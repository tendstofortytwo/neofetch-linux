#include <unistd.h>
#include <string.h>
#include <stdio.h>

int main(int argc, char** argv) {
	char* hostname;
	if(argc == 2) hostname = argv[1];
	else hostname = "neofetch-linux";
	int retval = sethostname(hostname, strlen(hostname));
	if(retval) perror(argv[0]);
	return retval;
}
