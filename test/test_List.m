clear all;
close all;
clc;

b1 = BubbleMMT();
b1.pos = [1,11,111];

b2 = Bubble();
b2.pos = [2,22,222];

b3 = Bubble();
b3.pos = [3,33,333];

b4 = Bubble();
b4.pos = [4,44,444];

bl_a = BubbleScatterers([1,11,111 ; 2,22,222 ; 3,33,333 ; 4,44,444], [ b1; b2 ; b3 ; b4 ]);
bl_b = BubbleScatterers([1,2,3 ; 4,5,6 ; 7,8,9 ; 10,11,12], [ b1; b2 ; b3 ; b4 ]);

sl_a = LinearScatterers(rand(100,3), rand(100,1));
sl_b = LinearScatterers(rand(100,3), rand(100,1));



%a.pos = cell2mat(arrayfun(@(b) b.pos, a, 'UniformOutput', false))