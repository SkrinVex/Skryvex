/// Трекер активного экрана — чтобы не показывать пуш если чат уже открыт
class ActiveScreen {
  ActiveScreen._();
  static final instance = ActiveScreen._();

  int? chatId;
  int? groupId;
  int? channelId;

  bool isChatActive(int id) => chatId == id;
  bool isGroupActive(int id) => groupId == id;
  bool isChannelActive(int id) => channelId == id;
}
