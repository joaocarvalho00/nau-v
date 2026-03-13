// syscalls.c — Minimal string library for NauV bare-metal
// Provides strcpy, strcmp, strlen used by Dhrystone.

char *strcpy(char *dest, const char *src)
{
    char *d = dest;
    while ((*d++ = *src++) != '\0')
        ;
    return dest;
}

int strcmp(const char *s1, const char *s2)
{
    while (*s1 && (*s1 == *s2)) {
        s1++;
        s2++;
    }
    return (unsigned char)*s1 - (unsigned char)*s2;
}

int strlen(const char *s)
{
    int n = 0;
    while (*s++) n++;
    return n;
}
