"""Summarize x64/ARM64 WinRT stowed errors from a CI-only Windows crash dump."""
import json
import mmap
import struct
import sys


def inspect(path):
    with open(path, "rb") as source, mmap.mmap(source.fileno(), 0, access=mmap.ACCESS_READ) as data:
        unpack = lambda fmt, offset: struct.unpack_from("<" + fmt, data, offset)
        if data[:4] != b"MDMP":
            raise ValueError("Not a Windows minidump")
        count, directory = unpack("II", 8)
        streams = {kind: (size, rva) for kind, size, rva in (unpack("III", directory + index * 12) for index in range(count))}
        memory = []
        if 9 in streams:
            size, rva = streams[9]
            ranges, cursor = unpack("QQ", rva)
            for index in range(ranges):
                address, length = unpack("QQ", rva + 16 + index * 16)
                memory.append((address, length, cursor))
                cursor += length
        if 5 in streams:
            size, rva = streams[5]
            ranges, = unpack("I", rva)
            memory.extend(unpack("QII", rva + 4 + index * 16) for index in range(ranges))

        def read(address, length):
            for start, size, rva in memory:
                if start <= address and address + length <= start + size:
                    return data[rva + address - start:rva + address - start + length]
            raise ValueError(f"Memory unavailable at {address:#x}")

        def word(address):
            return struct.unpack("<Q", read(address, 8))[0]

        modules = []
        if 4 in streams:
            size, rva = streams[4]
            entries, = unpack("I", rva)
            for index in range(entries):
                base, length, checksum, timestamp, name = unpack("QIIII", rva + 4 + index * 108)
                text_length, = unpack("I", name)
                text = data[name + 4:name + 4 + text_length].decode("utf-16-le")
                modules.append((base, length, text.replace("\\", "/").rsplit("/", 1)[-1]))

        def location(address):
            for base, length, name in modules:
                if base <= address < base + length:
                    return f"{name}+{address - base:#x}"
            return f"{address:#x}"

        size, rva = streams[6]
        code, = unpack("I", rva + 8)
        parameters, = unpack("I", rva + 32)
        arguments = unpack("Q" * parameters, rva + 40)
        result = {"exception": f"{code:#x}", "stowed": []}
        if code == 0xC000027B and len(arguments) >= 2:
            for index in range(min(arguments[1], 32)):
                address = word(arguments[0] + index * 8)
                length, signature, status, form = struct.unpack("<IIII", read(address, 16))
                error = {"hresult": f"{status:#x}", "form": form & 3}
                if form & 3 == 1:
                    error["address"] = location(word(address + 16))
                    word_size, words = struct.unpack("<II", read(address + 24, 8))
                    stack = word(address + 32)
                    if word_size == 8:
                        error["stack"] = [location(word(stack + item * 8)) for item in range(min(words, 96))]
                elif form & 3 == 2:
                    pointer = word(address + 16)
                    text = bytearray()
                    for item in range(8192):
                        character = read(pointer + item * 2, 2)
                        if character == b"\0\0":
                            break
                        text.extend(character)
                    error["message"] = text.decode("utf-16-le", errors="replace")
                if length >= 56:
                    error["nestedType"] = read(address + 40, 4).decode("ascii", errors="replace")
                result["stowed"].append(error)
        return result


if __name__ == "__main__":
    print(json.dumps(inspect(sys.argv[1]), ensure_ascii=False, indent=2))
