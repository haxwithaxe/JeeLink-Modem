#include <Ports.h>
#include <RF12.h>

#define ID 1
#define BAND 9 // aka 915MHz
#define GROUP 212
#define COLLECT 0x20

static byte cmd,dest,sendLen,dgroup,sendbuf[RF12_MAXDATA];

typedef struct {
    byte nodeId;
    byte group;
    char msg[RF12_MAXDATA];
    word crc = ~0;
} RF12packet;

static RF12packet packet;

static void handleInput (char c) {
        switch (c) {
            case 's': // send packet to node ID N, no ack
                cmd = c;
                dest = (Serial.read() - '0')*10 + (Serial.read() - '0');
                dgroup = (Serial.read() - '0')*100 + (Serial.read() - '0')*10 + (Serial.read() - '0');
                for (byte i = 0; i < RF12_MAXDATA; ++i){
                  char ch = Serial.read();
                  if (ch == -1) ch = 0;
                  packet.msg[i] = ch;
                }

                sendLen = sizeof(packet.msg);

                packet.crc = _crc16_update(~0, packet.group);
                for (byte i = 0; i < sizeof packet - 2; ++i)
                    packet.crc = _crc16_update(packet.crc, ((byte*) &config)[i]);
                break;
        }
}

void setup() {
    Serial.begin(57600);
    Serial.print("\nSERVER ON:");
    rf12_initialize(ID,BAND,GROUP);
}

void loop() {
    if (Serial.available())
        handleInput(Serial.read());

    if (rf12_recvDone()) {
        byte n = rf12_len;
        Serial.print("\n SENDER ID: ");
        Serial.print(rf12_hdr & RF12_HDR_MASK,DEC);
        Serial.print(" DATA:");
        for (byte i = 0; i < n; ++i) {
            Serial.print(' ');
            Serial.print((int) rf12_data[i]);
        }
        Serial.println();
    }

    if (rf12_crc == 0){
            if ((rf12_hdr & ~RF12_HDR_MASK) == RF12_HDR_ACK && (ID & COLLECT) == 0) {
                Serial.println("ACK");
                byte addr = rf12_hdr & RF12_HDR_MASK;
                // if request was sent only to us, send ack back as broadcast
                rf12_sendStart(rf12_hdr & RF12_HDR_DST ? RF12_HDR_CTL : RF12_HDR_CTL | RF12_HDR_DST | addr, 0, 0);
            }

    }

    if (cmd && rf12_canSend()) {

        Serial.print((int) sendLen);
        Serial.println("B");
        byte header = RF12_HDR_ACK;
        if (dest) header |= RF12_HDR_DST | dest;
        rf12_sendStart(header, packet.msg, sendLen);
        cmd = 0;

    }
}
