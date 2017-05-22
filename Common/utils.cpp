#include "utils.h"
#include <sstream>
#include <iomanip>
#include <Windows.h>

std::string Utils::GetFormattedWindowsErrorMsg()
{
    DWORD error = GetLastError();
    LPSTR message = NULL;

    DWORD flags = (FORMAT_MESSAGE_ALLOCATE_BUFFER |
                   FORMAT_MESSAGE_FROM_SYSTEM |
                   FORMAT_MESSAGE_IGNORE_INSERTS);
    DWORD lang_id = MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT);
    DWORD ret = FormatMessageA(flags, NULL, error, lang_id, (LPSTR)message, 0, NULL);

    std::ostringstream sstr;

    if (ret != 0) {
        sstr << message << " ";
    }

    sstr << "[" << error << "]";
    LocalFree(message);

    return sstr.str();
}

std::string Utils::DataToHex(const char *data, size_t length)
{
    std::ostringstream sstr;

    for (int i = 0; i < length; ++i) {
        int value = static_cast<int>(static_cast<unsigned char>(data[i]));
        sstr << std::hex << std::setw(2) << std::setfill('0') << value  << " ";
    }

    return sstr.str();
}

std::string Utils::DataToHex(const std::vector<char> &data)
{
    return Utils::DataToHex(data.data(), data.size());
}

std::wstring Utils::StrToWide(const std::string &str)
{
    int buf_size = MultiByteToWideChar(CP_ACP, MB_PRECOMPOSED, str.c_str(), -1, NULL, 0);
    if (buf_size == 0) {
        throw std::runtime_error("Error converting string: " + Utils::GetFormattedWindowsErrorMsg());
    }

    wchar_t* wide_name = new wchar_t[buf_size];

    if (!MultiByteToWideChar(CP_ACP, MB_PRECOMPOSED, str.c_str(), -1, wide_name, buf_size)) {
         throw std::runtime_error("Error converting string: " + Utils::GetFormattedWindowsErrorMsg());
    }

    std::wstring wide_str = wide_name;
    delete [] wide_name;

    return wide_str;
}

std::vector<char> Utils::StreambufToVector(boost::asio::streambuf &buf)
{
    using namespace boost::asio;

    std::vector<char> data(buf.size());
    buffer_copy(buffer(data), buf.data());
    buf.consume(buf.size());

    return data;
}
