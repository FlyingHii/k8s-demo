# Use a minimal Go base image
FROM golang:1.22-alpine AS builder

# Set the working directory
WORKDIR /app

# Copy go.mod and go.sum and download dependencies
COPY go.mod .
COPY go.sum .
# Install git for go mod download if needed
RUN apk add --no-cache git
RUN go mod download

# Copy the source code
COPY src/ .

# Build the application
RUN CGO_ENABLED=0 GOOS=linux go build -o /gin-app main.go

## Use a minimal base image for the final stage
#FROM alpine:latest as runner
#
## Install ca-certificates to ensure SSL works for external calls if needed
#RUN apk --no-cache add ca-certificates
#
## Set the working directory
#WORKDIR /root/
#
## Copy the built executable from the builder stage
#COPY --from=builder /gin-app .
#
## Expose the port the app listens on
#EXPOSE 8080
#
## Command to run the executable
#CMD ["./gin-app"]
