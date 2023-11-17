local ffi = require('ffi');
ffi.cdef[[
    int MultiByteToWideChar(uint32_t CodePage, uint32_t dwFlags, char* lpMultiByteStr, int cbMultiByte, wchar_t* lpMultiByteStr, int32_t cchWideChar);
    int WideCharToMultiByte(uint32_t CodePage, uint32_t dwFlags, wchar_t* lpWideCharString, int32_t cchWideChar, char* lpMultiByteStr, int32_t cbMultiByte, char lpDefaultChar);
]]

local exports = T{};

function exports:ShiftJIS_To_UTF8(input)
    local buffer = ffi.new('char[4096]');
    ffi.copy(buffer, input);
    local wBuffer = ffi.new("wchar_t[4096]");
    ffi.C.MultiByteToWideChar(932, 0, buffer, -1, wBuffer, 4096);
    ffi.C.WideCharToMultiByte(65001, 0, wBuffer, -1, buffer, 4096, 0);
    return ffi.string(buffer);
end

function exports:UTF8_To_ShiftJIS(input)
    local buffer = ffi.new('char[4096]');
    ffi.copy(buffer, input);
    local wBuffer = ffi.new("wchar_t[4096]");
    ffi.C.MultiByteToWideChar(65001, 0, buffer, -1, wBuffer, 4096);
    ffi.C.WideCharToMultiByte(932, 0, wBuffer, -1, buffer, 4096, 0);
    return ffi.string(buffer);
end

return exports;