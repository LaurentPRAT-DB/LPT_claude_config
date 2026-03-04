FROM ubuntu:22.04

# Avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install required tools (simulating a fresh laptop)
RUN apt-get update && apt-get install -y \
    curl \
    git \
    jq \
    python3 \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Create test user (simulates colleague's fresh environment)
RUN useradd -m -s /bin/bash colleague
USER colleague
ENV HOME=/home/colleague
WORKDIR /home/colleague

# Copy test script
COPY --chown=colleague:colleague test-full-install.sh /home/colleague/
RUN chmod +x /home/colleague/test-full-install.sh

# Default command
CMD ["/home/colleague/test-full-install.sh"]
