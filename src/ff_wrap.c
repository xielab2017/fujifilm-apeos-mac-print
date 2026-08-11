#include <unistd.h>
#include <stdlib.h>
int main(int argc, char **argv) {
  char *bin = "/Library/Printers/FUJIFILM/Filter/FFACMMCFilter.bin";
  char **na = malloc(sizeof(char*) * (argc + 3));
  if (!na) return 1;
  na[0] = "arch"; na[1] = "-x86_64"; na[2] = bin;
  for (int i = 1; i < argc; i++) na[i + 2] = argv[i];
  na[argc + 2] = NULL;
  execv("/usr/bin/arch", na);
  return 127;
}
