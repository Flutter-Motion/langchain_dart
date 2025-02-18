part of open_a_i_schema;

@freezed
class CreateChatCompletionStreamResponseContent with _$CreateChatCompletionStreamResponseContent {
  const factory CreateChatCompletionStreamResponseContent({
    required String text,
  }) = _CreateChatCompletionStreamResponseContent;

  factory CreateChatCompletionStreamResponseContent.fromJson(Map<String, dynamic> json) => _$CreateChatCompletionStreamResponseContentFromJson(json);
}