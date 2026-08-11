#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <iconv.h>
#include <errno.h>

static int ack(int fd, const char *step) {
  char c; ssize_t n = read(fd, &c, 1);
  if (n != 1 || c != 0) { fprintf(stderr, "ERROR: ack %s\n", step); return -1; }
  return 0;
}

static int to_gbk(const char *in, char *out, size_t outsz) {
  iconv_t cd = iconv_open("GBK", "UTF-8");
  if (cd == (iconv_t)-1) cd = iconv_open("CP936", "UTF-8");
  if (cd == (iconv_t)-1) { snprintf(out, outsz, "%s", "PrintJob"); return 0; }
  char *ip = (char*)in; size_t il = strlen(in);
  char *op = out; size_t ol = outsz - 1;
  if (iconv(cd, &ip, &il, &op, &ol) == (size_t)-1) {
    iconv_close(cd); snprintf(out, outsz, "%s", "PrintJob"); return 0;
  }
  *op = 0; iconv_close(cd);
  for (char *p = out; *p; p++) if (*p == '\n' || *p == '\r') *p = ' ';
  return 0;
}

int main(int argc, char **argv) {
  if (argc == 1) {
    puts("network lpdgbk \"Unknown\" \"LPD (GBK job name)\"");
    return 0;
  }
  const char *uri = getenv("DEVICE_URI");
  if (!uri) uri = argv[0];
  const char *hostp = strstr(uri, "://");
  if (!hostp) { fprintf(stderr, "ERROR: bad uri\n"); return 1; }
  hostp += 3;
  char host[128]={0}, queue[64]={0};
  sscanf(hostp, "%127[^/]/%63s", host, queue);
  /* strip port */
  char *colon = strchr(host, ':'); if (colon) *colon = 0;

  int job_id = atoi(argv[1]);
  const char *user = argv[2];
  const char *title = argv[3];
  char title_gbk[512]; to_gbk(title, title_gbk, sizeof title_gbk);

  FILE *inf = (argc >= 7) ? fopen(argv[6], "rb") : stdin;
  if (!inf) { fprintf(stderr, "ERROR: open input\n"); return 1; }
  fseek(inf, 0, SEEK_END); long sz = (inf == stdin) ? -1 : ftell(inf);
  if (inf != stdin) rewind(inf);

  unsigned char *data = NULL; size_t dlen = 0;
  if (sz >= 0) {
    data = malloc(sz); dlen = fread(data, 1, sz, inf);
  } else {
    size_t cap = 1<<20; data = malloc(cap); dlen = 0; size_t n;
    while ((n = fread(data + dlen, 1, cap - dlen, inf)) > 0) {
      dlen += n; if (dlen == cap) { cap *= 2; data = realloc(data, cap); }
    }
  }
  if (inf != stdin) fclose(inf);

  char ctrl[1024];
  int jn = job_id % 1000;
  int clen = snprintf(ctrl, sizeof ctrl,
    "HMacStudio\nP%.31s\nJ%s\nC%s\nN%s\ndfA%03dMacStudio\n",
    user, title_gbk, title_gbk, title_gbk, jn);

  int fd = socket(AF_INET, SOCK_STREAM, 0);
  struct sockaddr_in addr = {0};
  addr.sin_family = AF_INET; addr.sin_port = htons(515);
  if (inet_pton(AF_INET, host, &addr.sin_addr) != 1) {
    fprintf(stderr, "ERROR: bad host %s\n", host); return 1;
  }
  if (connect(fd, (struct sockaddr*)&addr, sizeof addr) < 0) {
    fprintf(stderr, "ERROR: connect: %s\n", strerror(errno)); return 1;
  }

  char buf[256];
  int n = snprintf(buf, sizeof buf, "\x02%s\n", queue);
  write(fd, buf, n); if (ack(fd, "recvjob")) return 1;
  n = snprintf(buf, sizeof buf, "\x02%d cfA%03dMacStudio\n", clen, jn);
  write(fd, buf, n); if (ack(fd, "ctrlhdr")) return 1;
  write(fd, ctrl, clen); write(fd, "\x00", 1); if (ack(fd, "ctrldata")) return 1;
  n = snprintf(buf, sizeof buf, "\x03%zu dfA%03dMacStudio\n", dlen, jn);
  write(fd, buf, n); if (ack(fd, "datahdr")) return 1;
  size_t off = 0; while (off < dlen) {
    ssize_t w = write(fd, data + off, dlen - off); if (w <= 0) break; off += w;
  }
  write(fd, "\x00", 1); if (ack(fd, "datadata")) return 1;
  close(fd); free(data);
  fprintf(stderr, "INFO: lpdgbk sent %zu bytes title_gbk\n", dlen);
  return 0;
}
