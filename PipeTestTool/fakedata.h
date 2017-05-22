#ifndef FAKEDATA_H
#define FAKEDATA_H

#include <cstdint>

class FakeData
{
public:
    struct ether_header
    {
        unsigned char ether_dhost[6];
        unsigned char ether_shost[6];
        unsigned short ether_type;
    };

    struct agent_hdr
    {
        unsigned short hdr_ifindex;
        unsigned short hdr_vrf;
        unsigned short hdr_cmd;
        unsigned int hdr_cmd_param;
        unsigned int hdr_cmd_param_1;
        unsigned int hdr_cmd_param_2;
        unsigned int hdr_cmd_param_3;
        unsigned int hdr_cmd_param_4;
        uint8_t hdr_cmd_param_5;
        uint8_t hdr_cmd_param_5_pack[3];
    };

    static const ether_header FakeEtherHdr;
    static const agent_hdr FakeAgentHdr;
};

#endif // FAKEDATA_H
