// Local-only CASC UI extractor. Never enables CDN downloads or writes to storage.
#include "CascLib.h"
#include <algorithm>
#include <cctype>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <set>
#include <sstream>
#include <string>
#include <vector>
namespace fs = std::filesystem;

static bool WINAPI progress(void*, CASC_PROGRESS_MSG message, LPCSTR object, DWORD current, DWORD total) {
    if (message != CascProgressLoadingIndexes || current == 0 || current == total)
        std::cerr << "CASC progress " << static_cast<int>(message) << ": " << (object ? object : "")
                  << " " << current << "/" << total << "\n";
    return false;
}

static std::string quote(const std::string& s) {
    std::string out = "\"";
    for (unsigned char c : s) {
        if (c == '\\' || c == '"') { out += '\\'; out += c; }
        else if (c < 32) { out += "?"; }
        else out += c;
    }
    return out + "\"";
}
static std::string hex(const BYTE* p, size_t n) {
    static const char* digits = "0123456789abcdef";
    std::string s;
    for (size_t i = 0; i < n; ++i) { s += digits[p[i] >> 4]; s += digits[p[i] & 15]; }
    return s;
}
static bool safePath(const std::string& name) {
    if (name.rfind("interface/", 0) != 0) return false;
    for (const auto& component : fs::path(name))
        if (component == ".." || component == ".") return false;
    static const std::set<std::string> extensions = {".blp", ".tga", ".lua", ".xml", ".toc", ".ttf", ".otf", ".fnt"};
    return extensions.count(fs::path(name).extension().string()) != 0;
}
int main(int argc, char** argv) {
    if (argc != 7) {
        std::cerr << "Usage: extract STORAGE PRODUCT CANDIDATES_CSV OUTPUT_DIR RESULT_JSONL MAX_BYTES\n";
        return 2;
    }
    fs::path storagePath = fs::canonical(argv[1]);
    fs::path outputPath = fs::weakly_canonical(argv[4]);
    fs::path logPath = fs::weakly_canonical(argv[5]);
    auto insideStorage = [&](const fs::path& p) {
        auto rel = p.lexically_relative(storagePath);
        return rel.empty() || *rel.begin() != "..";
    };
    if (insideStorage(outputPath) || insideStorage(logPath)) {
        std::cerr << "Output must be outside the game installation.\n"; return 2;
    }
    std::ifstream candidates(argv[3]);
    if (!candidates) { std::cerr << "Cannot open candidate list\n"; return 2; }
    const uint64_t maxBytes = std::stoull(argv[6]);
    HANDLE storage = nullptr;
    CASC_OPEN_STORAGE_ARGS args{};
    args.Size = sizeof(args);
    args.szLocalPath = argv[1];
    args.szCodeName = argv[2];
    args.dwLocaleMask = CASC_LOCALE_ENUS;
    args.dwFlags = 0; // No online/allow-download flags.
    args.PfnProgressCallback = progress;
    if (!CascOpenStorageEx(nullptr, &args, false, &storage)) {
        std::cerr << "CascOpenStorageEx failed: " << GetCascError() << "\n"; return 1;
    }
    std::cerr << "Opened local product " << argv[2] << "\n";
    fs::create_directories(outputPath);
    fs::create_directories(logPath.parent_path());
    std::ofstream log(logPath);
    uint64_t totalBytes = 0, successes = 0, missing = 0, failures = 0, limits = 0, checked = 0;
    std::string line;
    while (std::getline(candidates, line)) {
        size_t separator = line.find(';');
        if (separator == std::string::npos) continue;
        DWORD requestedId;
        try { requestedId = static_cast<DWORD>(std::stoul(line.substr(0, separator))); }
        catch (...) { continue; }
        std::string name = line.substr(separator + 1);
        if (!name.empty() && name.back() == '\r') name.pop_back();
        std::replace(name.begin(), name.end(), '\\', '/');
        std::transform(name.begin(), name.end(), name.begin(), [](unsigned char c) { return std::tolower(c); });
        if (!safePath(name)) continue;
        ++checked;
        HANDLE file = nullptr;
        // FileDataID is resolved through the selected product's ROOT. Shared Data
        // archives alone are never treated as membership in this product.
        if (!CascOpenFile(storage, CASC_FILE_DATA_ID(requestedId), CASC_LOCALE_ENUS,
                          CASC_OPEN_BY_FILEID | CASC_STRICT_DATA_CHECK, &file)) {
            ++missing;
            log << "{\"path\":" << quote(name) << ",\"requestedFileDataId\":" << requestedId
                << ",\"status\":\"unavailable\",\"error\":" << GetCascError() << "}\n";
            continue;
        }
        ULONGLONG size = 0;
        CASC_FILE_FULL_INFO info{};
        bool valid = CascGetFileSize64(file, &size) &&
            CascGetFileInfo(file, CascFileFullInfo, &info, sizeof(info), nullptr);
        if (!valid || size > (32ull << 20) || size > maxBytes - totalBytes) {
            ++limits;
            log << "{\"path\":" << quote(name) << ",\"requestedFileDataId\":" << requestedId
                << ",\"status\":\"skipped_limit_or_metadata\",\"size\":" << size << "}\n";
            CascCloseFile(file); continue;
        }
        std::vector<char> data(static_cast<size_t>(size));
        DWORD read = 0;
        if (!CascReadFile(file, data.data(), static_cast<DWORD>(size), &read) || read != size) {
            ++failures;
            log << "{\"path\":" << quote(name) << ",\"requestedFileDataId\":" << requestedId
                << ",\"status\":\"read_failed\",\"error\":" << GetCascError() << "}\n";
            CascCloseFile(file); continue;
        }
        fs::path destination = outputPath / name;
        fs::create_directories(destination.parent_path());
        std::ofstream output(destination, std::ios::binary);
        output.write(data.data(), static_cast<std::streamsize>(size));
        output.close();
        if (!output) { std::cerr << "Output write failed: " << destination << "\n"; return 1; }
        totalBytes += size; ++successes;
        log << "{\"path\":" << quote(name) << ",\"requestedFileDataId\":" << requestedId
            << ",\"fileDataId\":" << info.FileDataId << ",\"status\":\"extracted\",\"size\":" << size
            << ",\"ckey\":" << quote(hex(info.CKey, 16)) << ",\"ekey\":" << quote(hex(info.EKey, 16))
            << ",\"localeFlags\":" << info.LocaleFlags << ",\"contentFlags\":" << info.ContentFlags << "}\n";
        CascCloseFile(file);
        if (successes % 500 == 0) std::cerr << "Extracted " << successes << " files, " << totalBytes << " bytes\n";
    }
    CascCloseStorage(storage);
    std::cerr << "Finished checked=" << checked << " extracted=" << successes << " bytes=" << totalBytes
              << " unavailable=" << missing << " read_failed=" << failures << " skipped=" << limits << "\n";
    return successes ? 0 : 1;
}
