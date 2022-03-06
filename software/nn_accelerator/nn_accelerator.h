#ifndef __NN_A_H
#define __NN_A_H

#include "../_core/hardware.h"


typedef struct {
    _IO32 w0_0;
    _IO32 w1_0;
    _IO32 w0_1;
    _IO32 w1_1;
    _IO32 w0_2;
    _IO32 w1_2;
    _IO32 x0;
    _IO32 x1;
    _IO32 y1;
}nn_a_t;

#define NN_A_BASE ((nn_a_t *) &NN_A_BASE_ADDRESS)


int8_t inference(int8_t x0, int8_t x1);
void set_weigh(int8_t w0, int8_t x1, int8_t x2);


#endif