#include <stdio.h>
#include <sys/types.h>

#ifdef _WIN32

#include <ws2tcpip.h>
#include <winsock2.h>

#define tcp_socket      SOCKET
#define tcp_errno       WSAGetLastError()
#define tcp_errno_name  "WSA"
#define TCP_SEND_FLAGS  0

#else

#include <errno.h>
#include <netdb.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <sys/file.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <arpa/inet.h>

#define tcp_socket      int
#define tcp_errno       errno
#define tcp_errno_name  strerror(tcp_errno)
#define TCP_SEND_FLAGS  MSG_NOSIGNAL


#endif

#ifdef _WIN32
char tcp_started = 0;
int tcp_startup() {
	if (!tcp_started) {
		WSADATA wsa_data;
		if (WSAStartup(MAKEWORD(2,2), &wsa_data))
			return error_return(8003, tcp_errno);
		tcp_started = 1;
	}
	return 0;
}
#else
int tcp_startup() { return 0; }
#endif


int tcp_socket_create(tcp_socket *sock) {
	*sock = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
	#ifdef _WIN32
		if(*sock == INVALID_SOCKET)
	#else
		if(*sock < 0)
	#endif
			return error_return(8001, tcp_errno, tcp_errno_name);
	return 0;
}

int tcp_socket_close(tcp_socket sock) {
	#ifdef _WIN32
		if (closesocket(sock))
	#else
		if (close(sock))
	#endif
			return error_return(8004, tcp_errno, tcp_errno_name);
	return 0;
}

int tcp_connect(tcp_socket sock, char *address, int port) {
	struct sockaddr_in sock_address;
	memset(&sock_address, 0, sizeof(sock_address));
	sock_address.sin_addr.s_addr = inet_addr(address);
	sock_address.sin_port = htons(port);
	sock_address.sin_family = AF_INET;
    if(connect(sock, (struct sockaddr *) &sock_address, sizeof(sock_address)))
    	return error_return(8002, address, port, tcp_errno, tcp_errno_name);
    return 0;
}

int tcp_send(tcp_socket sock, char *data, size_t data_len) {
	for (size_t send_len=0; data_len>send_len; ) {
		int len = send(sock, data+send_len, data_len-send_len, 0);
		if (len<=0)
			return error_return(8005, tcp_errno, tcp_errno_name);
		send_len += len;
	}
	return 0;
}

int tcp_recv(tcp_socket sock, char *data, size_t data_size, size_t *data_len) {
	int free_size = data_size-*data_len-1;
	if (free_size==0) return error_return(8008, data_size);
	int recv_len = recv(sock, data+*data_len, free_size, 0);
	if (recv_len==0
	#ifdef _WIN32
		|| (recv_len<0 && tcp_errno==10060)
	#endif
	)
		return error_return(8006);
	*data_len += recv_len;
	data[*data_len] = 0;
	return 0;
}

int tcp_recv_http(tcp_socket sock, int *http_code, char *data, size_t data_size, size_t *data_len) {
	data[*data_len=0] = 0;
	size_t http_data_len;
	char *ptr, *ptr_headers_end;
	do {
		if (tcp_recv(sock, data, data_size, data_len)) return 1;
	} while((ptr_headers_end=strstr(data, "\r\n\r\n"))==NULL);
	ptr_headers_end += 4;
	ptr = strchr(data, ' '); if (ptr==NULL) return error_return(8013);
	ptr = strchr(ptr,  ' '); if (ptr==NULL) return error_return(8013);
	*http_code = atoi(ptr+1);
	ptr = strstr(ptr, "\nContent-Length: "); if (ptr==NULL) return error_return(8013);
	http_data_len = atoi(ptr+17);
	*data_len = (data+*data_len-ptr_headers_end);
	for(int i=0; i<=*data_len; i++) data[i] = ptr_headers_end[i];
	while(*data_len<http_data_len) {
		if (tcp_recv(sock, data, data_size, data_len)) return 1;
	}
	return 0;
}

int tcp_http_request(char *address, int port, char *auth, char *uri, char *content_type, char *data, size_t data_size, size_t *data_len) {
	if (address==NULL || port<=0 || uri==NULL || data==NULL)
		return error_return(8011);
	tcp_socket sock;
	char auth_header[256] = "";
	char request[1024];
	int http_code;
	if (auth[0])
		snprintf(auth_header, sizeof(auth_header), "Authorization: Basic %s\r\n", auth);
	snprintf(request, sizeof(request), "GET %s HTTP/1.1\r\nHost: %s\r\nAccept: %s\r\nAccept-Charset: UTF-8\r\n%s\r\n", uri, address, content_type, auth_header);
	if (tcp_startup() || tcp_socket_create(&sock)) return 1;
	int error = tcp_connect(sock, address, port) ||	tcp_send(sock, request, strlen(request)) ||	tcp_recv_http(sock, &http_code, data, data_size, data_len);
	if (tcp_socket_close(sock)) return 1;
	if (!error && http_code!=200)
		return http_code==401 ? error_return(8014) : error_return(8009, http_code, data);
	return error;
}

int tcp_address_hostname(char *address, size_t address_size, const char *hostname) {
	if (tcp_startup()) return 1;
	struct addrinfo *addr_info = NULL;
	struct addrinfo hints;
	memset(&hints, 0, sizeof(hints));
	hints.ai_family   = AF_INET;
	hints.ai_socktype = SOCK_STREAM;
	hints.ai_protocol = IPPROTO_TCP;
	int eai_errno;
	if (eai_errno=getaddrinfo(hostname, NULL, &hints, &addr_info))
	    return error_return(8012, hostname, "ai_", eai_errno);
	struct sockaddr_in *saddr_in = (struct sockaddr_in *) addr_info->ai_addr;
	if (inet_ntop(addr_info->ai_family, &(saddr_in->sin_addr), address, address_size)==NULL)
		return error_return(8012, hostname, "", tcp_errno);
	freeaddrinfo(addr_info);
	return 0;
}
