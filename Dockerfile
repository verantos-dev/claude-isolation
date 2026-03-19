FROM node:22-bookworm-slim

# Fix broken packages from base image
RUN apt-get update && dpkg --configure -a || true

# Security: Use specific user ID and avoid conflicts
ARG USER_ID=1001
ARG USER_NAME=claude

# Create non-root user with specific UID/GID
RUN groupadd -g ${USER_ID} ${USER_NAME} && \
    useradd -m -u ${USER_ID} -g ${USER_ID} -s /bin/bash ${USER_NAME}

# Install system dependencies with security hardening
RUN apt-get update && apt-get install -y --no-install-recommends \
    git curl wget ca-certificates python3 python3-pip build-essential xz-utils \
    # Security packages
    dumb-init \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /tmp/* \
    && rm -rf /var/tmp/* \
    # Remove unnecessary setuid binaries
    && find / -xdev -perm -4000 -type f -exec chmod u-s {} \; 2>/dev/null || true \
    && find / -xdev -perm -2000 -type f -exec chmod g-s {} \; 2>/dev/null || true \
    # Remove network tools that could be used for reconnaissance (but keep essential shells)
    && rm -f /usr/bin/nc /usr/bin/netcat /bin/netstat /usr/bin/ss || true

# Install basic Python tools
RUN pip3 install --no-cache-dir --break-system-packages \
    requests \
    python-dotenv

# Install Python security tools
RUN pip3 install --no-cache-dir --break-system-packages \
    semgrep \
    solc-select

# Setup solc-select with a default Solidity compiler
RUN solc-select install 0.8.20 && solc-select use 0.8.20

# Setup pnpm environment
ENV PNPM_HOME="/root/.local/share/pnpm"
ENV PATH="$PNPM_HOME:$PATH"

# Install pnpm
RUN wget -qO- https://get.pnpm.io/install.sh | ENV="$HOME/.shrc" SHELL="$(which sh)" sh -

# Enable pnpm via corepack
RUN corepack enable && corepack prepare pnpm@latest --activate

# Install Node.js tools
RUN pnpm add -g \
    typescript \
    ts-node \
    prettier \
    eslint \
    solhint \
    @infisical/cli

# Install Foundry (Solidity toolkit)
RUN curl -L https://foundry.paradigm.xyz | bash
ENV PATH="/root/.foundry/bin:$PATH"
RUN /root/.foundry/bin/foundryup
RUN cp -r /root/.foundry /home/${USER_NAME}/ && chown -R ${USER_NAME}:${USER_NAME} /home/${USER_NAME}/

# Install Determinate Nix (multi-user, for use with flake.nix in repos)
# Note: This may fail in some container environments due to seccomp restrictions
#RUN curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | \
#    sh -s -- install linux --no-confirm --init none \
#    && . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh \
#    && nix --version
#   || true

# Ensure claude user can access the Nix store (if Nix is installed)
#RUN (getent group nixbld > /dev/null && usermod -aG nixbld ${USER_NAME} || true) \
#    && mkdir -p /home/${USER_NAME}/.config/nix \
#    && echo 'experimental-features = nix-command flakes' > /home/${USER_NAME}/.config/nix/nix.conf \
#    && chown -R ${USER_NAME}:${USER_NAME} /home/${USER_NAME}/.config

# Install Claude Code (as claude user)
RUN su - ${USER_NAME} -c "export PNPM_HOME=/home/${USER_NAME}/.local/share/pnpm && export PATH=\$PNPM_HOME:\$PATH && pnpm add -g @anthropic-ai/claude-code"

################ Configure MCP Providers  --->

# Copy pre-built MCP server into container (from mcp/chonky)
#COPY --chown=${USER_NAME}:${USER_NAME} mcp/chonky /workspace/mcp-servers/chonky-mcp-server

# Install MCP server runtime dependencies only (using package-lock.json for exact versions)
#RUN cd /workspace/mcp-servers/chonky-mcp-server && pnpm install --prod --frozen-lockfile

# Don't forget to configure the MCP in claude-config.json

################# <--- Configure MCP Providers 

# Setup secure workspace with proper permissions
RUN mkdir -p /workspace/input \
    && mkdir -p /workspace/output \
    && mkdir -p /workspace/data \
    && mkdir -p /workspace/temp \
    && mkdir -p /workspace/mcp-servers \
    && chown -R ${USER_NAME}:${USER_NAME} /workspace \
    && chmod 755 /workspace \
    && chmod 750 /workspace/input \
    && chmod 750 /workspace/data \
    && chmod 755 /workspace/output \
    && chmod 755 /workspace/temp \
    && chmod 755 /workspace/mcp-servers


# Copy the working Claude config
COPY --chown=${USER_NAME}:${USER_NAME} claude-config.json /tmp/claude-config.json
COPY --chown=${USER_NAME}:${USER_NAME} settings.local.json /tmp/settings.local.json

# Setup Claude configuration (as root, will switch to claude user)
RUN echo '#!/bin/bash\n\
set -e\n\
echo "Setting up Claude configuration..."\n\
\n\
# Switch to claude user for configuration\n\
su - claude << "EOF_CLAUDE_USER"\n\
set -e\n\
cd /workspace\n\
\n\
# Copy the pre-configured Claude config\n\
cp /tmp/claude-config.json ~/.claude.json\n\
\n\
# Create .claude directory and copy settings.local.json\n\
mkdir -p ~/.claude\n\
cp /tmp/settings.local.json ~/.claude/settings.local.json\n\
mkdir -p /workspace/.claude\n\
cp /tmp/settings.local.json /workspace/.claude/settings.local.json\n\
\n\
echo "Claude configuration complete"\n\
ls -la ~/.claude.json\n\
ls -la ~/.claude/settings.local.json\n\
ls -la /workspace/.claude/settings.local.json\n\
\n\
EOF_CLAUDE_USER\n\
\n\
' > /usr/local/bin/configure-claude.sh \
    && chmod +x /usr/local/bin/configure-claude.sh \
    && /usr/local/bin/configure-claude.sh

# Switch to non-root user for security
USER ${USER_NAME}
WORKDIR /workspace
ENV PATH="/home/${USER_NAME}/.foundry/bin:$PATH"

# Create simple startup script for runtime
#RUN echo '#!/bin/bash\n\
#set -e\n\
#echo "Getting git repo..."\n\
#mkdir code\n\
#git clone https://${GH_PAT}@github.com/verantos-dev/verantos-evidence-platform.git code/\n\
#cd code\n\
#git fetch\n\
#git checkout ${GH_BRANCH}\n\
#cd ..\n\
#echo "Starting Claude Code..."\n\
## Use environment variable for API key\n\
## Run Claude Code with dangerous skip permissions for jailfree mode\n\
#exec claude --dangerously-skip-permissions "$@"\n\
#' > /home/${USER_NAME}/start-claude.sh \
#    && chmod +x /home/${USER_NAME}/start-claude.sh

# Security: Set secure environment variables and limits
ENV DEBIAN_FRONTEND=noninteractive \
    NODE_ENV=production \
    NPM_CONFIG_AUDIT=false \
    NPM_CONFIG_FUND=false \
    PNPM_HOME="/home/claude/.local/share/pnpm" \
    PATH="/home/claude/.local/share/pnpm:$PATH" \
    # Prevent core dumps
    RLIMIT_CORE=0 \
    # Limit file descriptors
    RLIMIT_NOFILE=1024 \
    # Prevent ptrace (debugging other processes)
    YAMA_PTRACE_SCOPE=1

# Add security labels
LABEL security.non-root=true \
      security.hardened=true \
      security.version="1.0"

# Health check
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
  CMD test -f ~/.claude/settings.json || exit 1

COPY startup_script.sh /home/${USER_NAME}/start-claude.sh

# Security: Use dumb-init for proper signal handling and process reaping
ENTRYPOINT ["dumb-init", "--", "/home/claude/start-claude.sh"]
