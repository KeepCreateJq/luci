#include <unistd.h>
#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>

#include <sys/socket.h>
#include <sys/time.h>
#include <sys/types.h>
#include <arpa/inet.h>
#include <netinet/in.h>
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <netdb.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <time.h>
int val;

static int inet_c(lua_State *L){

    struct sockaddr_in addr_s;
    short int fd=-1;
    fd_set fdset;
    struct timeval tv;
    int rc;
    int so_error;
    socklen_t len;
    struct timespec tstart={0,0}, tend={0,0};

    const char *addr = lua_tostring(L, -3);
    int port = atoi(lua_tostring(L, -2));
    int seconds = atoi(lua_tostring(L, -1));
    addr_s.sin_family = AF_INET; // utilizzo IPv4
    addr_s.sin_addr.s_addr = inet_addr(addr);
    addr_s.sin_port = htons(port);

    clock_gettime(CLOCK_MONOTONIC, &tstart);

    fd = socket(AF_INET, SOCK_STREAM, 0);
    fcntl(fd, F_SETFL, O_NONBLOCK); // setup non blocking socket

    // make the connection
    rc = connect(fd, (struct sockaddr *)&addr_s, sizeof(addr_s));
    if ((rc == -1) && (errno != EINPROGRESS)) {
        lua_pushstring(L, "false");
        return 1;
        close(fd);
        return 1;
    }
    if (rc == 0) {
        // connection has succeeded immediately
        clock_gettime(CLOCK_MONOTONIC, &tend);
        lua_pushstring(L, "true");
        return 1;

        close(fd);
        return 0;
    } /*else {
        // connection attempt is in progress
    } */

    FD_ZERO(&fdset);
    FD_SET(fd, &fdset);
    tv.tv_sec = seconds;
    tv.tv_usec = 0;

    rc = select(fd + 1, NULL, &fdset, NULL, &tv);
    switch(rc) {
    case 1: // data to read
        len = sizeof(so_error);

        getsockopt(fd, SOL_SOCKET, SO_ERROR, &so_error, &len);

        if (so_error == 0) {
            clock_gettime(CLOCK_MONOTONIC, &tend);
            lua_pushstring(L, "true");
        return 1;
            close(fd);
            return 0;
        } else { // error
            lua_pushstring(L, "false");
            return 1;
        }
        break;
    case 0: //timeout
	lua_pushstring(L, "false");
        return 1;
        break;
    }

    close(fd);
    lua_pushnumber(L, 6);
    return 0;
}

/* Register function */
int luaopen_firewrt(lua_State *L){
	lua_register( L, "inet", inet_c);
        lua_pushstring(L, "true");
	return 1;
}
