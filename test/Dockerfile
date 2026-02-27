# Dockerfile for testing Claude Code setup script
# Note: This tests on Linux with Homebrew - not identical to macOS but validates script logic

FROM ubuntu:24.04

# Prevent interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install base dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    build-essential \
    procps \
    file \
    sudo \
    locales \
    && rm -rf /var/lib/apt/lists/*

# Set locale
RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# Create a non-root user for Homebrew (required)
RUN useradd -m -s /bin/bash testuser && \
    echo "testuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Switch to testuser and set HOME correctly
USER testuser
ENV HOME=/home/testuser
WORKDIR /home/testuser

# Install Homebrew
RUN /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Add Homebrew to PATH
ENV PATH="/home/linuxbrew/.linuxbrew/bin:${PATH}"

# Clone the config repo (simulating fresh install)
RUN git clone https://github.com/LaurentPRAT-DB/LPT_claude_config.git /home/testuser/.claude

# Set working directory to .claude
WORKDIR /home/testuser/.claude

# Default command - run the setup script
CMD ["/bin/bash", "-c", "echo '=== Testing Setup Script ===' && ./setup.sh"]
