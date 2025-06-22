#include <unistd.h>
#include <string.h>
#include <fcntl.h>
#include <sys/reboot.h>

int main() {
    const char* hello = "Hello, world!\n";
    const char* exit_msg = "Press RETURN to exit\n";
    int fd = open("/dev/console", O_RDWR);

    if (fd >= 0) {
        write(fd, hello, strlen(hello));
        write(fd, exit_msg, strlen(exit_msg));

        char ch;
        for (;;) {
            if (read(fd, &ch, 1) != 1) continue;
            if (ch == '\n') break;
        }
        write(fd, "Shutting down...\n", 18);
        sync();
        reboot(RB_POWER_OFF);
    } else {
        write(STDERR_FILENO, "Could not open /dev/console\n", 28);
    }

    for (;;) pause();
    return 0;
}
