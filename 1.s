lui	v0,0x8000
ori	v0,v0,0x1200
lw	a0,0(v0)
lui	a0,0x1000
ori	a0,a0,0xffff
sw	a0,0(v0)
cache	0x1,0(v0)
cache	0x0,0(v0)
cache	0x8,0(v0)
cache	0x8,4096(v0)
cache	0x8,8192(v0)
cache	0x8,12288(v0)
lw	a0,0(v0)
move	zero,zero
move	zero,zero
lui	v0,0x8000
cache	0x0,0(v0)
cache	0x8,0(v0)
cache	0x8,4096(v0)
move	zero,zero
move	zero,zero