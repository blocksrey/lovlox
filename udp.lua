-- Load the FFI library
local ffi = require("ffi")

-- Define the sockaddr_in structure for socket address information
ffi.cdef[[
    typedef uint16_t in_port_t;
    typedef uint32_t in_addr_t;
    struct in_addr {
        in_addr_t s_addr;
    };
    struct sockaddr_in {
        short sin_family;
        in_port_t sin_port;
        struct in_addr sin_addr;
        char sin_zero[8];
    };
    int socket(int domain, int type, int protocol);
    int bind(int sockfd, const struct sockaddr_in *addr, socklen_t addrlen);
    ssize_t sendto(int sockfd, const void *buf, size_t len, int flags, const struct sockaddr_in *dest_addr, socklen_t addrlen);
    ssize_t recvfrom(int sockfd, void *buf, size_t len, int flags, struct sockaddr_in *src_addr, socklen_t *addrlen);
    int close(int fd);
]]

-- Constants for socket types and protocols
local AF_INET = 2
local SOCK_DGRAM = 2
local IPPROTO_UDP = 17

-- Create a UDP socket
local sockfd = ffi.C.socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
if sockfd == -1 then
    error("Failed to create socket")
end

-- Create a sockaddr_in structure for the local address (you can change the IP and port as needed)
local local_addr = ffi.new("struct sockaddr_in")
local_addr.sin_family = AF_INET
local_addr.sin_port = ffi.C.htons(12345)  -- Port number
local_addr.sin_addr.s_addr = ffi.C.INADDR_ANY  -- Any available network interface

-- Bind the socket to the local address
if ffi.C.bind(sockfd, local_addr, ffi.sizeof(local_addr)) == -1 then
    error("Failed to bind socket")
end

-- Example: Sending data via UDP
local dest_addr = ffi.new("struct sockaddr_in")
dest_addr.sin_family = AF_INET
dest_addr.sin_port = ffi.C.htons(54321)  -- Destination port number
dest_addr.sin_addr.s_addr = ffi.C.inet_addr("127.0.0.1")  -- Destination IP address

local message = "Hello, UDP!"
local bytes_sent = ffi.C.sendto(sockfd, message, #message, 0, dest_addr, ffi.sizeof(dest_addr))
if bytes_sent == -1 then
    error("Failed to send data")
end

-- Example: Receiving data via UDP
local buffer_size = 1024
local buffer = ffi.new("char[?]", buffer_size)
local src_addr = ffi.new("struct sockaddr_in")
local addrlen = ffi.new("socklen_t[1]", ffi.sizeof(src_addr))
local bytes_received = ffi.C.recvfrom(sockfd, buffer, buffer_size, 0, src_addr, addrlen)
if bytes_received == -1 then
    error("Failed to receive data")
else
    local received_message = ffi.string(buffer, bytes_received)
    print("Received: " .. received_message)
end

-- Close the socket when done
ffi.C.close(sockfd)
