import contextlib
import importlib.util
import io
from pathlib import Path
import plistlib
import struct
import unittest
import zipfile

spec = importlib.util.spec_from_file_location("ipa_verifier", Path(__file__).with_name("verify-unsigned-ipa.py"))
verifier = importlib.util.module_from_spec(spec)
spec.loader.exec_module(verifier)


def macho(platform=2, dependency=None, rpath=None, signature=False):
    commands = [struct.pack("<6I", 0x32, 24, platform, 0x120000, 0x1A0000, 0)]
    for command, value, header_size in [(0xC, dependency, 24), (0x8000001C, rpath, 12)]:
        if value:
            size = (header_size + len(value.encode()) + 1 + 7) // 8 * 8
            commands.append((struct.pack("<3I", command, size, header_size) + b"\0" * (header_size - 12)
                             + value.encode() + b"\0").ljust(size, b"\0"))
    if signature:
        commands.append(struct.pack("<4I", 0x1D, 16, 0, 0))
    return struct.pack("<8I", 0xFEEDFACF, 0x0100000C, 0, 2, len(commands), sum(map(len, commands)), 0, 0) + b"".join(commands)


class ArtifactTests(unittest.TestCase):
    def artifact(self, binary=None, extras=None, migration=True):
        contents = {
            "Info.plist": plistlib.dumps(dict(CFBundleIdentifier="com.example.EuroGas", CFBundleExecutable="EuroGas",
                                             CFBundleShortVersionString="0.1.0", CFBundleVersion="1", CFBundlePackageType="APPL",
                                             CFBundleSupportedPlatforms=["iPhoneOS"], NSSupportsLiveActivities=False, MinimumOSVersion="18.0")),
            "EuroGas": binary if binary is not None else macho(), "Assets.car": b"fixture",
        }
        if migration:
            contents["Persistence_Persistence.bundle/v1_initial.sql"] = b"fixture"
        contents.update(extras or {})
        output = io.BytesIO()
        with zipfile.ZipFile(output, "w") as archive:
            for name, data in contents.items():
                archive.writestr("Payload/EuroGas.app/" + name, data)
        output.seek(0)
        return output

    def test_valid_device_artifact(self):
        with contextlib.redirect_stdout(io.StringIO()):
            verifier.verify(self.artifact())

    def test_rejects_simulator_signature_tests_and_missing_resource(self):
        for fixture, message in [(self.artifact(binary=macho(platform=7)), "physical iOS"),
                                 (self.artifact(binary=macho(signature=True)), "code signature"),
                                 (self.artifact(extras={"Frameworks/XCTest.framework/XCTest": macho()}), "test component"),
                                 (self.artifact(migration=False), "migration resource")]:
            with self.subTest(message=message), self.assertRaisesRegex(ValueError, message):
                verifier.verify(fixture)

    def test_embedded_framework_needs_a_resolvable_runpath(self):
        library = {"Frameworks/Example.framework/Example": macho()}
        dependency = "@rpath/Example.framework/Example"
        with self.assertRaisesRegex(ValueError, "Unresolved runtime dependency"):
            verifier.verify(self.artifact(binary=macho(dependency=dependency), extras=library))
        with contextlib.redirect_stdout(io.StringIO()):
            verifier.verify(self.artifact(binary=macho(dependency=dependency, rpath="@executable_path/Frameworks"), extras=library))


if __name__ == "__main__":
    unittest.main()
