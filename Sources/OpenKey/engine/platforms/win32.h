//
// win32.h
// Windows Virtual-Key codes mapping for OpenKey engine
//

#ifndef OPENKEY_WIN32_H
#define OPENKEY_WIN32_H

// Virtual-Key codes for Windows
#define KEY_ESC                                 0x1B // VK_ESCAPE
#define KEY_DELETE                              0x08 // VK_BACK (backspace)
#define KEY_TAB                                 0x09 // VK_TAB
// Windows has no separate keypad Enter VK (it is 0x0D + extended flag).
// Win32 host must map extended-0x0D (numpad enter) to 0x0E.
#define KEY_ENTER                               0x0E
#define KEY_RETURN                              0x0D // VK_RETURN
#define KEY_SPACE                               0x20 // VK_SPACE
#define KEY_LEFT                                0x25 // VK_LEFT
#define KEY_UP                                  0x26 // VK_UP
#define KEY_RIGHT                               0x27 // VK_RIGHT
#define KEY_DOWN                                0x28 // VK_DOWN

#define KEY_EMPTY                               256

// Letters 'A'..'Z' (0x41..0x5A)
#define KEY_A                                   0x41
#define KEY_B                                   0x42
#define KEY_C                                   0x43
#define KEY_D                                   0x44
#define KEY_E                                   0x45
#define KEY_F                                   0x46
#define KEY_G                                   0x47
#define KEY_H                                   0x48
#define KEY_I                                   0x49
#define KEY_J                                   0x4A
#define KEY_K                                   0x4B
#define KEY_L                                   0x4C
#define KEY_M                                   0x4D
#define KEY_N                                   0x4E
#define KEY_O                                   0x4F
#define KEY_P                                   0x50
#define KEY_Q                                   0x51
#define KEY_R                                   0x52
#define KEY_S                                   0x53
#define KEY_T                                   0x54
#define KEY_U                                   0x55
#define KEY_V                                   0x56
#define KEY_W                                   0x57
#define KEY_X                                   0x58
#define KEY_Y                                   0x59
#define KEY_Z                                   0x5A

// Digits '0'..'9' (0x30..0x39)
#define KEY_0                                   0x30
#define KEY_1                                   0x31
#define KEY_2                                   0x32
#define KEY_3                                   0x33
#define KEY_4                                   0x34
#define KEY_5                                   0x35
#define KEY_6                                   0x36
#define KEY_7                                   0x37
#define KEY_8                                   0x38
#define KEY_9                                   0x39

// Brackets and punctuation
#define KEY_LEFT_BRACKET                        0xDB // VK_OEM_4 ('[{')
#define KEY_RIGHT_BRACKET                       0xDD // VK_OEM_6 ('}]')

#define KEY_LEFT_SHIFT                          0xA0 // VK_LSHIFT
#define KEY_RIGHT_SHIFT                         0xA1 // VK_RSHIFT
#define KEY_DOT                                 0xBE // VK_OEM_PERIOD

#define KEY_BACKQUOTE                           0xC0 // VK_OEM_3 ('`~')
#define KEY_MINUS                               0xBD // VK_OEM_MINUS ('-_')
#define KEY_EQUALS                              0xBB // VK_OEM_PLUS ('=+')
#define KEY_BACK_SLASH                          0xDC // VK_OEM_5 ('\|')
#define KEY_SEMICOLON                           0xBA // VK_OEM_1 (';:')
#define KEY_QUOTE                               0xDE // VK_OEM_7 ('"'')
#define KEY_COMMA                               0xBC // VK_OEM_COMMA ('<,')
#define KEY_SLASH                               0xBF // VK_OEM_2 ('/?')

#endif // OPENKEY_WIN32_H
