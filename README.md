# test_audio_devices

Flutter app to test audio_session and flutter_webrtc on new added device events

Logic NOTES:

mute during a call - out of scope
handle/check mic in headset - out of scope (need to have screen to test the hardware)

discover:
Multipoint Bluetooth topic

Андроид системная логика
- первым включить проводные наушики, потом бле - три устройства доступны [проводная гарнитура, бле, общий динамик, ушной динамик]
- первым включить бле, потом проводные - бле отключается, остается [проводная гарнитура, динамик]
- если любое устройство добавлять к динамику оно всегда в приоритете. [проводная гарнитура/бле,  динамик]

иОС системная логика
- 


 - добавить опцию earpeace для случаев когда нет гарнитуры
 - логика подписки на состояние подключенных устройств должна быть в общем цикле (не только во врмя звонка). 