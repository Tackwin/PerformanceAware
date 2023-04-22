#scope_file
#import "Tagged_Union";

#scope_export
Reg :: enum {
	AL :: 0;
	AX :: 1;
	CL :: 2;
	CX :: 3;
	DL :: 4;
	DX :: 5;
	BL :: 6;
	BX :: 7;
	AH :: 8;
	SP :: 9;
	CH :: 10;
	BP :: 11;
	DH :: 12;
	SI :: 13;
	BH :: 14;
	DI :: 15;
	ES :: 16;
	CS :: 17;
	SS :: 18;
	DS :: 19;
	None;
};

Cea :: enum {
	BX_SI :: 0;
	BX_DI :: 1;
	BP_SI :: 2;
	BP_DI :: 3;
	SI :: 4;
	DI :: 5;
	BP :: 6;
	BX :: 7;

	ES;
	ES_BX_SI :: ES;
	ES_BX_DI;
	ES_BP_SI;
	ES_BP_DI;
	ES_SI;
	ES_DI;
	ES_BP;
	ES_BX;

	CS;
	CS_BX_SI :: CS;
	CS_BX_DI;
	CS_BP_SI;
	CS_BP_DI;
	CS_SI;
	CS_DI;
	CS_BP;
	CS_BX;

	SS;
	SS_BX_SI :: SS;
	SS_BX_DI;
	SS_BP_SI;
	SS_BP_DI;
	SS_SI;
	SS_DI;
	SS_BP;
	SS_BX;

	DS;
	DS_BX_SI :: DS;
	DS_BX_DI;
	DS_BP_SI;
	DS_BP_DI;
	DS_SI;
	DS_DI;
	DS_BP;
	DS_BX;
};
Direct_Address :: struct {
	addr: u16;
	seg: Reg = .None;
}

Nullary_Op :: struct { }

Prefix :: struct { }

Binary_Op :: struct {
	src: Tagged_Union(Reg, Cea, Direct_Address, u8, u16);
	dst: Tagged_Union(Reg, Cea, Direct_Address, u8);

	disp: s16;
}

Conditional_Jump :: struct {
	delta: s8;
}

Jump :: struct {
	disp: s16;
	far: bool;

	has_direct_seg:= false;
	direct_seg: u16;
	src: Tagged_Union(Reg, Cea, Direct_Address, u8, u16, s16);
}

Unary_Op :: struct {
	op: Tagged_Union(Reg, Cea, Direct_Address, u8, u16);

	wide := false;
	disp: s16;
}

Shift_Op :: struct {
	src: Tagged_Union(Reg, u8);
	dst: Tagged_Union(Reg, Cea, Direct_Address);

	wide := false;
	disp: s16;
}

String_Op :: struct {
	wide := false;
}

MOV :: struct { #as using base: Binary_Op; name :: "mov"; }
ADD :: struct { #as using base: Binary_Op; name :: "add"; }
ADC :: struct { #as using base: Binary_Op; name :: "adc"; }
SUB :: struct { #as using base: Binary_Op; name :: "sub"; }
SBB :: struct { #as using base: Binary_Op; name :: "sbb"; }
CMP :: struct { #as using base: Binary_Op; name :: "cmp"; }
XCHG :: struct { #as using base: Binary_Op; name :: "xchg"; }
IN :: struct { #as using base: Binary_Op; name :: "in"; };
OUT :: struct { #as using base: Binary_Op; name :: "out"; };
LEA :: struct { #as using base: Binary_Op; name :: "lea"; };
LDS :: struct { #as using base: Binary_Op; name :: "lds"; };
LES :: struct { #as using base: Binary_Op; name :: "les"; };
AND :: struct { #as using base: Binary_Op; name :: "and"; };
TEST :: struct { #as using base: Binary_Op; name :: "test"; };
OR :: struct { #as using base: Binary_Op; name :: "or"; };
XOR :: struct { #as using base: Binary_Op; name :: "xor"; };

PUSH :: struct { #as using base: Unary_Op; name :: "push"; };
POP :: struct { #as using base: Unary_Op; name :: "pop"; };
INC :: struct { #as using base: Unary_Op; name :: "inc"; };
DEC :: struct { #as using base: Unary_Op; name :: "dec"; };
NEG :: struct { #as using base: Unary_Op; name :: "neg"; };
MUL :: struct { #as using base: Unary_Op; name :: "mul"; };
IMUL :: struct { #as using base: Unary_Op; name :: "imul"; };
DIV :: struct { #as using base: Unary_Op; name :: "div"; };
IDIV :: struct { #as using base: Unary_Op; name :: "idiv"; };
NOT :: struct { #as using base: Unary_Op; name :: "not"; };

JE :: struct { #as using base: Conditional_Jump; name :: "je"; }
JL :: struct { #as using base: Conditional_Jump; name :: "jl"; }
JLE :: struct { #as using base: Conditional_Jump; name :: "jle"; }
JB :: struct { #as using base: Conditional_Jump; name :: "jb"; }
JBE :: struct { #as using base: Conditional_Jump; name :: "jbe"; }
JP :: struct { #as using base: Conditional_Jump; name :: "jp"; }
JO :: struct { #as using base: Conditional_Jump; name :: "jo"; }
JS :: struct { #as using base: Conditional_Jump; name :: "js"; }
JNZ :: struct { #as using base: Conditional_Jump; name :: "jnz"; }
JGE :: struct { #as using base: Conditional_Jump; name :: "jge"; }
JG :: struct { #as using base: Conditional_Jump; name :: "jg"; }
JNB :: struct { #as using base: Conditional_Jump; name :: "jnb"; }
JA :: struct { #as using base: Conditional_Jump; name :: "ja"; }
JNP :: struct { #as using base: Conditional_Jump; name :: "jnp"; }
JNO :: struct { #as using base: Conditional_Jump; name :: "jno"; }
JNS :: struct { #as using base: Conditional_Jump; name :: "jns"; }
LOOP :: struct { #as using base: Conditional_Jump; name :: "loop"; }
LOOPZ :: struct { #as using base: Conditional_Jump; name :: "loopz"; }
LOOPNZ :: struct { #as using base: Conditional_Jump; name :: "loopnz"; }
JCXZ :: struct { #as using base: Conditional_Jump; name :: "jcxz"; }

CALL :: struct { #as using base: Jump; name :: "call"; }
JMP :: struct { #as using base: Jump; name :: "jmp"; }

XLAT :: struct { #as using base: Nullary_Op; name :: "xlat"; }
LAHF :: struct { #as using base: Nullary_Op; name :: "lahf"; }
SAHF :: struct { #as using base: Nullary_Op; name :: "sahf"; }
PUSHF :: struct { #as using base: Nullary_Op; name :: "pushf"; }
POPF :: struct { #as using base: Nullary_Op; name :: "popf"; }
AAA :: struct { #as using base: Nullary_Op; name :: "aaa"; }
DAA :: struct { #as using base: Nullary_Op; name :: "daa"; }
AAS :: struct { #as using base: Nullary_Op; name :: "aas"; }
DAS :: struct { #as using base: Nullary_Op; name :: "das"; }
AAM :: struct { #as using base: Nullary_Op; name :: "aam"; }
AAD :: struct { #as using base: Nullary_Op; name :: "aad"; }
CBW :: struct { #as using base: Nullary_Op; name :: "cbw"; }
CWD :: struct { #as using base: Nullary_Op; name :: "cwd"; }
INTO :: struct { #as using base: Nullary_Op; name :: "into"; }
IRET :: struct { #as using base: Nullary_Op; name :: "iret"; }
CLC :: struct { #as using base: Nullary_Op; name :: "clc"; }
CMC :: struct { #as using base: Nullary_Op; name :: "cmc"; }
STC :: struct { #as using base: Nullary_Op; name :: "stc"; }
CLD :: struct { #as using base: Nullary_Op; name :: "cld"; }
STD :: struct { #as using base: Nullary_Op; name :: "std"; }
CLI :: struct { #as using base: Nullary_Op; name :: "cli"; }
STI :: struct { #as using base: Nullary_Op; name :: "sti"; }
HLT :: struct { #as using base: Nullary_Op; name :: "hlt"; }
WAIT :: struct { #as using base: Nullary_Op; name :: "wait"; }

SHL :: struct { #as using base: Shift_Op; name :: "shl"; }
SHR :: struct { #as using base: Shift_Op; name :: "shr"; }
SAR :: struct { #as using base: Shift_Op; name :: "sar"; }
ROL :: struct { #as using base: Shift_Op; name :: "rol"; }
ROR :: struct { #as using base: Shift_Op; name :: "ror"; }
RCL :: struct { #as using base: Shift_Op; name :: "rcl"; }
RCR :: struct { #as using base: Shift_Op; name :: "rcr"; }

REP :: struct { #as using base: Prefix; name :: "rep"; Z := 0; }
LOCK :: struct { #as using base: Prefix; name :: "lock"; }
SEGMENT :: struct { #as using base: Prefix; name :: "segment"; reg: Reg; };

MOVS :: struct {#as using base: String_Op; name :: "movs"; }
CMPS :: struct {#as using base: String_Op; name :: "cmps"; }
SCAS :: struct {#as using base: String_Op; name :: "scas"; }
LODS :: struct {#as using base: String_Op; name :: "lods"; }
STOS :: struct {#as using base: String_Op; name :: "stos"; }

RET :: struct { name :: "ret"; far := false; to_add: u16; }

INT :: struct { name :: "int"; interrupt: u8; }

Instruction :: Tagged_Union(
	PUSH, POP, INC, DEC, NEG, MUL, IMUL, DIV, IDIV, NOT,
	MOV, ADD, ADC, SUB, SBB, CMP, XCHG, IN, OUT, LEA, LDS, LES, AND, TEST, OR, XOR,
	JE, JL, JLE, JB, JBE, JP, JO, JS, JNZ, JGE, JG, JNB, JA, JNP, JNO, JNS, LOOP, LOOPZ, LOOPNZ,
		JCXZ,
	CALL, JMP,
	XLAT, LAHF, SAHF, PUSHF, POPF, AAA, DAA, AAS, DAS, AAM, AAD, CBW, CWD, INTO, IRET, CLC, CMC,
	STC, CLD, STD, CLI, STI, HLT, WAIT,
	SHL, SHR, SAR, ROL, ROR, RCL, RCR,
	REP, LOCK,
	MOVS, CMPS, SCAS, LODS, STOS,
	RET,
	INT,
);
