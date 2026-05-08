#ifndef USRSUBRDEFS_H
#define USRSUBRDEFS_H 1
int UserSubr(int user_subr_index, int num_args, unsigned *args);
int block_until_event(int max_ms);
extern int desired_displaywidth;
extern int desired_displayheight;
int dsp_commit_resize(int new_w, int new_h);
#endif
