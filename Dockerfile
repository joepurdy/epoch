# Use an official Go runtime as a builder image
FROM public.ecr.aws/docker/library/golang:1.21-alpine as builder

# Set the working directory in the container
WORKDIR /app

# Copy the local source files to the container’s workspace.
ADD . /app

# Build the API
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o epoch-api .

# Use a minimal scratch image for the API runtime container
FROM scratch

# Copy the binary from the builder image
COPY --from=builder /app/epoch-api .

# Expose port the API listens on
EXPOSE 1337

# Run the API binary
CMD ["./epoch-api"]
