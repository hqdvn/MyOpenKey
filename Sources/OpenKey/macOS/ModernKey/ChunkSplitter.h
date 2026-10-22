//
//  ChunkSplitter.h
//  MyOpenKey
//
//  Pure chunk-splitting logic for synthetic Unicode key delivery.
//

#ifndef ChunkSplitter_h
#define ChunkSplitter_h

#include <vector>
#include <cstdint>
#include <cstddef>
#include <algorithm>

#ifndef PURE_CHARACTER_MASK
#define PURE_CHARACTER_MASK 0x80000000
#endif

#ifndef CHAR_CODE_MASK
#define CHAR_CODE_MASK 0x2000000
#endif

#ifndef IS_DOUBLE_CODE
#define IS_DOUBLE_CODE(code) ((code) == 2 || (code) == 3)
#endif

#ifndef LOBYTE
#define LOBYTE(w) ((uint8_t)((w) & 0xFF))
#endif

#ifndef HIBYTE
#define HIBYTE(w) ((uint8_t)(((uint16_t)(w) >> 8) & 0xFF))
#endif

#define MAX_CHUNK_UNITS 16
extern uint16_t _unicodeCompoundMark[];


struct CharUnits {
    uint16_t units[2];
    uint8_t count = 0;          // 1 or 2 UTF-16 units
    uint8_t syncKeyLength = 0;  // 0, 1, or 2 (used for InsertKeyLength)
};

// Pure function to expand a single token according to codeTable
template <typename KeyCodeFunc = uint16_t (*)(const uint32_t&)>
inline CharUnits expandCharToken(
    uint32_t tempChar,
    int codeTable,
    KeyCodeFunc keyCodeToCharFunc = nullptr,
    const uint16_t* compoundMarks = nullptr
) {
    CharUnits res;
    if (tempChar & PURE_CHARACTER_MASK) {
        res.units[0] = (uint16_t)tempChar;
        res.count = 1;
        if (IS_DOUBLE_CODE(codeTable)) {
            res.syncKeyLength = 1;
        }
    } else if (!(tempChar & CHAR_CODE_MASK)) {
        if (IS_DOUBLE_CODE(codeTable)) {
            res.syncKeyLength = 1;
        }
        res.units[0] = keyCodeToCharFunc ? keyCodeToCharFunc(tempChar) : (uint16_t)tempChar;
        res.count = 1;
    } else {
        if (codeTable == 0) { // Unicode
            res.units[0] = (uint16_t)tempChar;
            res.count = 1;
        } else if (codeTable == 1 || codeTable == 2 || codeTable == 4) { // TCVN3, VNI, CP1258
            uint16_t newChar = (uint16_t)tempChar;
            uint16_t lo = LOBYTE(newChar);
            uint16_t hi = HIBYTE(newChar);
            res.units[0] = lo;
            if (hi > 32) {
                if (codeTable == 2) {
                    res.syncKeyLength = 2;
                }
                res.units[1] = hi;
                res.count = 2;
            } else {
                if (codeTable == 2) {
                    res.syncKeyLength = 1;
                }
                res.count = 1;
            }
        } else if (codeTable == 3) { // Unicode Compound
            uint16_t newChar = (uint16_t)tempChar;
            uint16_t lo = newChar & 0x1FFF;
            uint16_t hi = (newChar >> 13);
            const uint16_t* marks = compoundMarks ? compoundMarks : _unicodeCompoundMark;
            res.syncKeyLength = (hi > 0) ? 2 : 1;
            res.units[0] = lo;
            if (hi > 0 && hi <= 5 && marks) {
                res.units[1] = marks[hi - 1];
                res.count = 2;
            } else {
                res.count = 1;
            }
        }
    }
    return res;
}

// Pure chunk-splitting function: groups tokens and optional restoreChar
// into chunks of max 16 UTF-16 units without dropping or splitting multi-unit characters.
template <typename KeyCodeFunc = uint16_t (*)(const uint32_t&)>
inline std::vector<std::vector<uint16_t>> splitIntoChunks(
    const std::vector<uint32_t>& tokens,
    int codeTable,
    uint16_t restoreChar = 0,
    KeyCodeFunc keyCodeToCharFunc = nullptr,
    const uint16_t* compoundMarks = nullptr
) {
    std::vector<std::vector<uint16_t>> chunks;
    std::vector<uint16_t> currentChunk;

    auto appendUnits = [&](const uint16_t* u, uint8_t cnt) {
        if (cnt == 0) return;
        if (currentChunk.size() + cnt > MAX_CHUNK_UNITS) {
            if (!currentChunk.empty()) {
                chunks.push_back(currentChunk);
                currentChunk.clear();
            }
        }
        for (uint8_t i = 0; i < cnt; i++) {
            currentChunk.push_back(u[i]);
        }
    };

    for (size_t i = 0; i < tokens.size(); i++) {
        CharUnits u = expandCharToken(tokens[i], codeTable, keyCodeToCharFunc, compoundMarks);
        appendUnits(u.units, u.count);
    }

    if (restoreChar != 0) {
        appendUnits(&restoreChar, 1);
    }

    if (!currentChunk.empty()) {
        chunks.push_back(currentChunk);
    }
    return chunks;
}

#endif /* ChunkSplitter_h */
