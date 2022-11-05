#include <sys/ioctl.h>
#include <unistd.h>

// Zig fail to translate TIOCGWINSZ correctly,
// so I have to use the C version here.
static int getWinsize(struct winsize *ws) {
	return ioctl(STDIN_FILENO, TIOCGWINSZ, ws);
}
