"""Validate the actual sideload artifact using only Python's standard library."""

import plistlib
import posixpath
import struct
import sys
import zipfile


def require(condition, message):
    if not condition:
        raise ValueError(message)


def inspect_macho(data, name):
    require(len(data) >= 32 and data[:4] == b"\xcf\xfa\xed\xfe", f"Not a 64-bit Mach-O: {name}")
    _, cpu, _, _, count, command_bytes, _, _ = struct.unpack_from("<8I", data)
    require(cpu == 0x0100000C, f"Not an arm64 iPhone binary: {name}")
    require(32 + command_bytes <= len(data), f"Truncated Mach-O: {name}")
    dependencies, rpaths = [], []
    offset = 32
    platform = None
    for _ in range(count):
        command, size = struct.unpack_from("<II", data, offset)
        require(size >= 8 and offset + size <= 32 + command_bytes, f"Invalid load command: {name}")
        if command in (0xC, 0x80000018, 0x8000001F, 0x20, 0x80000023, 0x8000001C):
            string_offset = struct.unpack_from("<I", data, offset + 8)[0]
            require(12 <= string_offset < size, f"Invalid load path: {name}")
            value = data[offset + string_offset:offset + size].split(b"\0", 1)[0].decode("utf-8")
            (rpaths if command == 0x8000001C else dependencies).append(value)
        if command == 0x32:  # LC_BUILD_VERSION: 2 = physical iOS, 7 = simulator.
            platform = struct.unpack_from("<I", data, offset + 8)[0]
        if command == 0x2C:  # LC_ENCRYPTION_INFO_64
            require(struct.unpack_from("<I", data, offset + 16)[0] == 0, f"Encrypted binary: {name}")
        require(command != 0x1D, f"Unexpected embedded code signature: {name}")
        offset += size
    require(offset == 32 + command_bytes, f"Invalid Mach-O command size: {name}")
    require(platform == 2, f"Binary is not built for physical iOS: {name}")
    return dependencies, rpaths


def verify(path):
    root = "Payload/EuroGas.app/"
    with zipfile.ZipFile(path) as archive:
        require(archive.testzip() is None, "ZIP integrity check failed")
        names = archive.namelist()
        require(len(names) == len(set(names)), "Duplicate ZIP entries")
        for name in names:
            require(name == "Payload/" or name.startswith(root), f"Unexpected path: {name}")
            require(".." not in name.split("/") and "\\" not in name, f"Unsafe path: {name}")
            require(not any(part == "_CodeSignature" or part == "embedded.mobileprovision"
                            or part == "PlugIns" or part.endswith((".appex", ".xctest"))
                            or part.startswith(("XCTest", "XCUnit", "XCUIAutomation", "XCTAutomation", "libXCTest"))
                            or part == "Testing.framework" for part in name.split("/")),
                    f"Signing, extension or test component in free IPA: {name}")
        info = plistlib.loads(archive.read(root + "Info.plist"))
        for key in ("CFBundleIdentifier", "CFBundleExecutable", "CFBundleShortVersionString", "CFBundleVersion"):
            require(bool(info.get(key)) and "$(" not in str(info[key]), f"Missing/unresolved {key}")
        require(info.get("CFBundlePackageType") == "APPL", "Not an application bundle")
        require(info.get("CFBundleSupportedPlatforms") == ["iPhoneOS"], "Not an iPhoneOS app")
        require(info.get("NSSupportsLiveActivities") is False, "Live Activities must be disabled for this IPA")
        executable = root + info["CFBundleExecutable"]
        binaries = {}
        for name in names:
            if name.endswith("/"):
                continue
            with archive.open(name) as stream:
                magic = stream.read(4)
            if magic == b"\xcf\xfa\xed\xfe":
                binaries[name] = inspect_macho(archive.read(name), name)
        require(executable in binaries, "Missing arm64 application executable")
        require(any(name.endswith("/v1_initial.sql") for name in names), "Database migration resource missing")
        require(root + "Assets.car" in names, "Compiled assets missing")

        def expand(value, binary):
            return posixpath.normpath(value.replace("@executable_path", root.rstrip("/"))
                                      .replace("@loader_path", posixpath.dirname(binary)))

        app_rpaths = [expand(value, executable) for value in binaries[executable][1]]
        for binary, (dependencies, rpaths) in binaries.items():
            search_paths = app_rpaths + [expand(value, binary) for value in rpaths]
            for dependency in dependencies:
                if dependency.startswith(("/System/Library/", "/usr/lib/")):
                    continue
                if dependency.startswith("@rpath/libswift"):
                    continue  # Swift runtime ships with the minimum supported iOS 18.
                candidates = ([posixpath.normpath(base + "/" + dependency[7:]) for base in search_paths]
                              if dependency.startswith("@rpath/") else [expand(dependency, binary)])
                require(any(candidate in binaries for candidate in candidates),
                        f"Unresolved runtime dependency in {binary}: {dependency}")
        print(f"PASS IPA: {info['CFBundleIdentifier']}, iOS {info.get('MinimumOSVersion')}, "
              f"{len(binaries)} arm64 binaries, valid resources and runtime dependencies")


if __name__ == "__main__":
    try:
        verify(sys.argv[1])
    except (ValueError, KeyError, OSError, zipfile.BadZipFile, struct.error) as error:
        sys.exit(f"IPA validation failed: {error}")
