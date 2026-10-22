//
//  chunk_test.cpp
//  Tests
//
//  Compile and run:
//  clang++ -std=c++14 Tests/chunk_test.cpp -I Sources/OpenKey/macOS/ModernKey -o Tests/chunk_test && ./Tests/chunk_test
//

#include "ChunkSplitter.h"
#include <cassert>
#include <iostream>
#include <vector>
uint16_t _unicodeCompoundMark[] = {0x0301, 0x0300, 0x0309, 0x0303, 0x0323};


// Helper to make a Unicode Compound 2-unit token (mark 1 = sắc -> 0x0301)
static uint32_t makeCompoundChar(uint16_t baseChar, uint8_t mark) {
    return ((uint32_t)(baseChar & 0x1FFF) | ((uint32_t)(mark & 0x7) << 13)) | CHAR_CODE_MASK;
}

// Helper to make a VNI / TCVN 2-unit token
static uint32_t makeVniDoubleChar(uint8_t lo, uint8_t hi) {
    return ((uint32_t)lo | ((uint32_t)hi << 8)) | CHAR_CODE_MASK;
}

// Helper to count total units across all chunks
static size_t totalUnits(const std::vector<std::vector<uint16_t>>& chunks) {
    size_t count = 0;
    for (const auto& ch : chunks) {
        assert(ch.size() <= MAX_CHUNK_UNITS);
        assert(!ch.empty());
        count += ch.size();
    }
    return count;
}

static void testMacro15() {
    std::cout << "Testing 15-char macros..." << std::endl;
    // 15 single-unit chars
    std::vector<uint32_t> tokens1(15, 'a' | CHAR_CODE_MASK);
    auto chunks1 = splitIntoChunks(tokens1, 0);
    assert(chunks1.size() == 1);
    assert(chunks1[0].size() == 15);
    assert(totalUnits(chunks1) == 15);

    // 14 single-unit chars + 1 2-unit char at boundary (code table 3: Unicode Compound)
    std::vector<uint32_t> tokens2(14, 'a' | CHAR_CODE_MASK);
    tokens2.push_back(makeCompoundChar('a', 1)); // 'á': emits 'a' + 0x0301 (2 units)
    assert(tokens2.size() == 15);
    auto chunks2 = splitIntoChunks(tokens2, 3);
    assert(chunks2.size() == 1);
    assert(chunks2[0].size() == 16);
    assert(totalUnits(chunks2) == 16);
    assert(chunks2[0][14] == 'a');
    assert(chunks2[0][15] == 0x0301);
}

static void testMacro16() {
    std::cout << "Testing 16-char macros..." << std::endl;
    // 16 single-unit chars: exactly fills 1 chunk
    std::vector<uint32_t> tokens1(16, 'a' | CHAR_CODE_MASK);
    auto chunks1 = splitIntoChunks(tokens1, 0);
    assert(chunks1.size() == 1);
    assert(chunks1[0].size() == 16);
    assert(totalUnits(chunks1) == 16);

    // 15 single-unit chars + 1 2-unit char at chunk boundary!
    // At token 15, current chunk has 15 units. 15 + 2 = 17 > 16, so chunk 0 must flush (15 units)
    // and chunk 1 must receive the 2-unit character intact (2 units).
    std::vector<uint32_t> tokens2(15, 'a' | CHAR_CODE_MASK);
    tokens2.push_back(makeCompoundChar('a', 1));
    assert(tokens2.size() == 16);
    auto chunks2 = splitIntoChunks(tokens2, 3);
    assert(chunks2.size() == 2);
    assert(chunks2[0].size() == 15);
    assert(chunks2[1].size() == 2);
    assert(totalUnits(chunks2) == 17);
    assert(chunks2[1][0] == 'a');
    assert(chunks2[1][1] == 0x0301);
}

static void testMacro17() {
    std::cout << "Testing 17-char macros..." << std::endl;
    // 16 single-unit chars + 1 2-unit char:
    // Chunk 0 has 16 units, Chunk 1 has 2 units.
    std::vector<uint32_t> tokens1(16, 'a' | CHAR_CODE_MASK);
    tokens1.push_back(makeCompoundChar('e', 2)); // 'è': 'e' + 0x0300
    assert(tokens1.size() == 17);
    auto chunks1 = splitIntoChunks(tokens1, 3);
    assert(chunks1.size() == 2);
    assert(chunks1[0].size() == 16);
    assert(chunks1[1].size() == 2);
    assert(totalUnits(chunks1) == 18);
    assert(chunks1[1][0] == 'e');
    assert(chunks1[1][1] == 0x0300);

    // 15 single-unit chars + 1 2-unit char + 1 single-unit char:
    // Chunk 0 has 15 units, Chunk 1 has 2 + 1 = 3 units.
    std::vector<uint32_t> tokens2(15, 'a' | CHAR_CODE_MASK);
    tokens2.push_back(makeCompoundChar('o', 3)); // 'ỏ': 'o' + 0x0309
    tokens2.push_back('z' | CHAR_CODE_MASK);
    assert(tokens2.size() == 17);
    auto chunks2 = splitIntoChunks(tokens2, 3);
    assert(chunks2.size() == 2);
    assert(chunks2[0].size() == 15);
    assert(chunks2[1].size() == 3);
    assert(totalUnits(chunks2) == 18);
    assert(chunks2[1][0] == 'o');
    assert(chunks2[1][1] == 0x0309);
    assert(chunks2[1][2] == 'z');
}

static void testMacro33() {
    std::cout << "Testing 33-char macros..." << std::endl;
    // Macro of 33 chars with 2-unit chars at boundaries:
    // tokens[0..14] = 15 single-unit chars (15 units)
    // token[15]     = 2-unit char (flushes chunk 0 at 15 units; starts chunk 1 with 2 units)
    // tokens[16..29]= 14 single-unit chars (chunk 1 gets 2 + 14 = 16 units, now full)
    // token[30]     = 2-unit char (flushes chunk 1 at 16 units; starts chunk 2 with 2 units)
    // tokens[31..32]= 2 single-unit chars (chunk 2 gets 2 + 2 = 4 units)
    std::vector<uint32_t> tokens;
    for (int i = 0; i < 15; i++) tokens.push_back('x' | CHAR_CODE_MASK);
    tokens.push_back(makeCompoundChar('u', 4)); // 'ũ': 2 units
    for (int i = 0; i < 14; i++) tokens.push_back('y' | CHAR_CODE_MASK);
    tokens.push_back(makeCompoundChar('i', 5)); // 'ị': 2 units
    tokens.push_back('a' | CHAR_CODE_MASK);
    tokens.push_back('b' | CHAR_CODE_MASK);
    assert(tokens.size() == 33);

    auto chunks = splitIntoChunks(tokens, 3);
    assert(chunks.size() == 3);
    assert(chunks[0].size() == 15);
    assert(chunks[1].size() == 16);
    assert(chunks[2].size() == 4);
    assert(totalUnits(chunks) == 35);
}

static void testMacro100() {
    std::cout << "Testing 100-char macros with boundary multi-unit characters..." << std::endl;
    std::vector<uint32_t> tokens;
    size_t expectedUnits = 0;
    for (int i = 0; i < 100; i++) {
        // Place 2-unit characters around boundaries (every 15-16 chars)
        if (i % 16 == 15) {
            tokens.push_back(makeCompoundChar('a', 1));
            expectedUnits += 2;
        } else {
            tokens.push_back('a' | CHAR_CODE_MASK);
            expectedUnits += 1;
        }
    }
    assert(tokens.size() == 100);

    auto chunks = splitIntoChunks(tokens, 3);
    assert(!chunks.empty());
    assert(totalUnits(chunks) == expectedUnits);
    for (const auto& ch : chunks) {
        assert(ch.size() <= MAX_CHUNK_UNITS);
        assert(!ch.empty());
    }
}

static void testAllCodeTables() {
    std::cout << "Testing all 5 code tables & InsertKeyLength bookkeeping..." << std::endl;
    // Table 0: Unicode (single unit, no sync length)
    CharUnits u0 = expandCharToken(0x00E1 | CHAR_CODE_MASK, 0);
    assert(u0.count == 1);
    assert(u0.units[0] == 0x00E1);
    assert(u0.syncKeyLength == 0);

    // Table 1: TCVN3 (newCharHi > 32 produces 2 units, sync length 0)
    CharUnits u1 = expandCharToken(makeVniDoubleChar(0x61, 0x42), 1);
    assert(u1.count == 2);
    assert(u1.units[0] == 0x61);
    assert(u1.units[1] == 0x42);
    assert(u1.syncKeyLength == 0);

    // Table 2: VNI Windows (newCharHi > 32 produces 2 units, sync length 2)
    CharUnits u2 = expandCharToken(makeVniDoubleChar(0x61, 0x45), 2);
    assert(u2.count == 2);
    assert(u2.units[0] == 0x61);
    assert(u2.units[1] == 0x45);
    assert(u2.syncKeyLength == 2);

    // Table 2: VNI Windows (newCharHi <= 32 produces 1 unit, sync length 1)
    CharUnits u2_single = expandCharToken(makeVniDoubleChar(0x61, 0x00), 2);
    assert(u2_single.count == 1);
    assert(u2_single.units[0] == 0x61);
    assert(u2_single.syncKeyLength == 1);

    // Table 3: Unicode Compound (newCharHi > 0 produces 2 units, sync length 2)
    CharUnits u3 = expandCharToken(makeCompoundChar('a', 1), 3);
    assert(u3.count == 2);
    assert(u3.units[0] == 'a');
    assert(u3.units[1] == 0x0301);
    assert(u3.syncKeyLength == 2);

    // Table 3: Unicode Compound (newCharHi == 0 produces 1 unit, sync length 1)
    CharUnits u3_single = expandCharToken('a' | CHAR_CODE_MASK, 3);
    assert(u3_single.count == 1);
    assert(u3_single.units[0] == 'a');
    assert(u3_single.syncKeyLength == 1);

    // Table 4: CP1258 (newCharHi > 32 produces 2 units, sync length 0)
    CharUnits u4 = expandCharToken(makeVniDoubleChar(0x61, 0x43), 4);
    assert(u4.count == 2);
    assert(u4.units[0] == 0x61);
    assert(u4.units[1] == 0x43);
    assert(u4.syncKeyLength == 0);

    // Pure character flag
    CharUnits uPure = expandCharToken('z' | PURE_CHARACTER_MASK, 2);
    assert(uPure.count == 1);
    assert(uPure.units[0] == 'z');
    assert(uPure.syncKeyLength == 1);
}

static void testRestoreChar() {
    std::cout << "Testing restore character..." << std::endl;
    // 16 chars + restore char -> chunk 0 has 16 units, chunk 1 has restore char (1 unit)
    std::vector<uint32_t> tokens(16, 'a' | CHAR_CODE_MASK);
    auto chunks = splitIntoChunks(tokens, 0, 'k');
    assert(chunks.size() == 2);
    assert(chunks[0].size() == 16);
    assert(chunks[1].size() == 1);
    assert(chunks[1][0] == 'k');
}

int main() {
    testMacro15();
    testMacro16();
    testMacro17();
    testMacro33();
    testMacro100();
    testAllCodeTables();
    testRestoreChar();
    std::cout << "ALL CHUNK TESTS PASSED!" << std::endl;
    return 0;
}
