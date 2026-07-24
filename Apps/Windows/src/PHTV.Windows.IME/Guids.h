#pragma once

#include <guiddef.h>

namespace phtv::windows::ime {

// {DBA10184-8C04-4FD4-922B-44A2F2B3264A}
inline constexpr CLSID text_service_clsid{
    0xdba10184,
    0x8c04,
    0x4fd4,
    {0x92, 0x2b, 0x44, 0xa2, 0xf2, 0xb3, 0x26, 0x4a},
};

// {8574EE1F-9BC9-47C5-9350-274C13D64317}
inline constexpr GUID vietnamese_profile_guid{
    0x8574ee1f,
    0x9bc9,
    0x47c5,
    {0x93, 0x50, 0x27, 0x4c, 0x13, 0xd6, 0x43, 0x17},
};

// {8F4952A7-7934-49B2-9A64-793906454873}
inline constexpr GUID toggle_language_preserved_key_guid{
    0x8f4952a7,
    0x7934,
    0x49b2,
    {0x9a, 0x64, 0x79, 0x39, 0x06, 0x45, 0x48, 0x73},
};

}  // namespace phtv::windows::ime
