FROM ubuntu:22.04

# Avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install required tools
RUN apt-get update && apt-get install -y \
    curl \
    git \
    jq \
    python3 \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Create test directory
WORKDIR /test

# Copy test script
COPY test-install.sh /test/test-install.sh
RUN chmod +x /test/test-install.sh

# Default command
CMD ["/test/test-install.sh"]
