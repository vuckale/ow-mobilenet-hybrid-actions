FROM openwhisk/action-rust-v1.34

# Set Rust version exactly as you did
RUN rustup default 1.83.0

# Copy your source into the container
WORKDIR /action
COPY . .

# Build the project
RUN cargo build --release --example mobilenet-oc-l
RUN cargo build --release --example add-l

# Move the binary to root (as you did manually)
RUN cp target/release/examples/mobilenet-oc-l /mobilenet-oc-l
RUN cp target/release/examples/add-l /add-l

# Run from root, just like you did
WORKDIR /
