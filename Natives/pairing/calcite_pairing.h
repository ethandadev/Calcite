#pragma once
#include <stddef.h>
#include <stdint.h>

typedef struct CalcitePairing CalcitePairing;
typedef void (*CalcitePairingPinCallback)(const char *pin, void *context);

CalcitePairing *calcite_pairing_new(const char *name, char **error);
uint16_t calcite_pairing_port(const CalcitePairing *s);
const char *calcite_pairing_service_name(const CalcitePairing *s);
size_t calcite_pairing_txt_count(const CalcitePairing *s);
const char *calcite_pairing_txt_key(const CalcitePairing *s, size_t i);
const char *calcite_pairing_txt_value(const CalcitePairing *s, size_t i);
/// 0 = paired, 1 = error, 2 = cancelled.
int32_t calcite_pairing_accept(const CalcitePairing *s, CalcitePairingPinCallback pin_cb, void *ctx,
                               uint8_t **out_plist, size_t *out_len, char **error);
void calcite_pairing_cancel(const CalcitePairing *s);
void calcite_pairing_free(CalcitePairing *s);
void calcite_pairing_bytes_free(uint8_t *bytes, size_t len);
void calcite_pairing_string_free(char *s);
