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

}  // namespace phtv::windows::ime
