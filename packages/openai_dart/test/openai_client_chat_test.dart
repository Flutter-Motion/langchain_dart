@TestOn('vm')
library; // Uses dart:io

import 'dart:convert';
import 'dart:io';

import 'package:openai_dart/openai_dart.dart';
import 'package:test/test.dart';

void main() {
  group('OpenAI Chat Completions API tests', () {
    late OpenAIClient client;

    setUp(() {
      client = OpenAIClient(
        apiKey: Platform.environment['OPENAI_API_KEY'],
      );
    });

    tearDown(() {
      client.endSession();
    });

    test('Test call chat completion API', () async {
      final models = [
        ChatCompletionModels.gpt4oMini,
        ChatCompletionModels.gpt4,
      ];

      for (final model in models) {
        final request = CreateChatCompletionRequest(
          model: ChatCompletionModel.model(model),
          messages: [
            const ChatCompletionMessage.system(
              content: 'You are a helpful assistant.',
            ),
            const ChatCompletionMessage.user(
              content: ChatCompletionUserMessageContent.string('Hello!'),
            ),
          ],
          temperature: 0,
          topLogprobs: 2,
          logprobs: true,
        );
        final CreateChatCompletionResponse res =
            await client.createChatCompletion(request: request);
        expect(res.choices, hasLength(1));
        final choice = res.choices.first;
        expect(choice.index, 0);
        expect(choice.finishReason, ChatCompletionFinishReason.stop);
        expect(choice.logprobs?.content, isNotEmpty);
        final logprob = choice.logprobs!.content!.first;
        expect(logprob.token, isNotEmpty);
        expect(logprob.bytes, isNotEmpty);
        expect(logprob.topLogprobs, hasLength(2));
        final topLogprob = logprob.topLogprobs.first;
        expect(topLogprob.token, isNotEmpty);
        expect(topLogprob.bytes, isNotEmpty);
        final message = choice.message;
        expect(message.role, ChatCompletionMessageRole.assistant);
        expect(message.content, isNotEmpty);
        expect(message.functionCall, isNull);
        expect(res.id, isNotEmpty);
        expect(res.created, greaterThan(0));
        expect(res.model, startsWith('gpt-'));
        expect(res.object, isNotEmpty);
        expect(res.usage?.promptTokens, greaterThan(0));
        expect(res.usage?.completionTokens, greaterThan(0));
        expect(res.usage?.totalTokens, greaterThan(0));
      }
    });

    test('Test call chat completion API with stop sequence', () async {
      const request = CreateChatCompletionRequest(
        model: ChatCompletionModel.model(
          ChatCompletionModels.gpt4oMini,
        ),
        messages: [
          ChatCompletionMessage.system(
            content:
                'You are a helpful assistant that replies only with numbers '
                'in order without any spaces or commas',
          ),
          ChatCompletionMessage.user(
            content: ChatCompletionUserMessageContent.string(
              'List the numbers from 1 to 9',
            ),
          ),
        ],
        maxTokens: 10,
        temperature: 0,
        stop: ChatCompletionStop.string('4'),
      );
      final res = await client.createChatCompletion(request: request);
      expect(res.choices, hasLength(1));
      final message = res.choices.first.message;
      expect(message.content?.trim(), contains('123'));
      expect(message.content?.trim(), isNot(contains('456789')));
      expect(
        res.choices.first.finishReason,
        ChatCompletionFinishReason.stop,
      );
    });

    test('Test call chat completions API with max tokens', () async {
      const request = CreateChatCompletionRequest(
        model: ChatCompletionModel.model(
          ChatCompletionModels.gpt4oMini,
        ),
        messages: [
          ChatCompletionMessage.system(
            content: 'You are a helpful assistant.',
          ),
          ChatCompletionMessage.user(
            content: ChatCompletionUserMessageContent.string('Tell me a joke'),
          ),
        ],
        maxCompletionTokens: 2,
      );
      final res = await client.createChatCompletion(request: request);
      expect(res.choices, isNotEmpty);
      expect(
        res.choices.first.finishReason,
        ChatCompletionFinishReason.length,
      );
      expect(
        res.usage?.completionTokensDetails?.reasoningTokens,
        ChatCompletionFinishReason.length,
      );
    });

    test('Test call chat completions API with other parameters', () async {
      const request = CreateChatCompletionRequest(
        model: ChatCompletionModel.model(
          ChatCompletionModels.gpt4oMini,
        ),
        messages: [
          ChatCompletionMessage.system(
            content: 'You are a helpful assistant.',
          ),
          ChatCompletionMessage.user(
            content: ChatCompletionUserMessageContent.string('Tell me a joke'),
          ),
        ],
        maxCompletionTokens: 2,
        presencePenalty: 0.6,
        frequencyPenalty: 0.6,
        logitBias: {'50256': -100},
        n: 2,
        temperature: 0,
        topP: 0.2,
        user: 'user_123',
      );
      final res = await client.createChatCompletion(request: request);
      expect(res.choices, hasLength(2));
    });

    test('Test call chat completions streaming API', () async {
      const request = CreateChatCompletionRequest(
        model: ChatCompletionModel.model(
          ChatCompletionModels.gpt4oMini,
        ),
        messages: [
          ChatCompletionMessage.system(
            content:
                'You are a helpful assistant that replies only with numbers '
                'in order without any spaces or commas',
          ),
          ChatCompletionMessage.user(
            content: ChatCompletionUserMessageContent.string(
              'List the numbers from 1 to 9',
            ),
          ),
        ],
        streamOptions: ChatCompletionStreamOptions(
          includeUsage: true,
        ),
      );
      final stream = client.createChatCompletionStream(request: request);
      String text = '';
      CreateChatCompletionStreamResponse? lastResponse;
      ChatCompletionStreamResponseChoice? lastChoice;
      await for (final res in stream) {
        expect(res.id, isNotEmpty);
        expect(res.created, greaterThan(0));
        expect(res.model, startsWith('gpt-4o-mini'));
        expect(res.object, isNotEmpty);
        if (res.choices.isNotEmpty) {
          expect(res.choices, hasLength(1));
          final choice = res.choices.first;
          expect(choice.index, 0);
          text += res.choices.first.delta.content?.trim() ?? '';
          lastChoice = choice;
        }
        lastResponse = res;
      }
      expect(lastChoice?.finishReason, ChatCompletionFinishReason.stop);
      expect(text, contains('123456789'));
      expect(lastResponse?.usage?.completionTokens, greaterThan(0));
      expect(lastResponse?.usage?.promptTokens, greaterThan(0));
      expect(lastResponse?.usage?.totalTokens, greaterThan(0));
    });

    test('Test call chat completions API tools', () async {
      const function = FunctionObject(
        name: 'get_current_weather',
        description: 'Get the current weather in a given location',
        parameters: {
          'type': 'object',
          'properties': {
            'location': {
              'type': 'string',
              'description': 'The city and state, e.g. San Francisco, CA',
            },
            'unit': {
              'type': 'string',
              'description': 'The unit of temperature to return',
              'enum': ['celsius', 'fahrenheit'],
            },
          },
          'required': ['location'],
        },
      );
      const tool = ChatCompletionTool(
        type: ChatCompletionToolType.function,
        function: function,
      );

      final request1 = CreateChatCompletionRequest(
        model: const ChatCompletionModel.model(
          ChatCompletionModels.gpt4oMini,
        ),
        messages: [
          const ChatCompletionMessage.system(
            content: 'You are a helpful assistant.',
          ),
          const ChatCompletionMessage.user(
            content: ChatCompletionUserMessageContent.string(
              'What’s the weather like in Boston right now?',
            ),
          ),
        ],
        tools: [tool],
        toolChoice: ChatCompletionToolChoiceOption.tool(
          ChatCompletionNamedToolChoice(
            type: ChatCompletionNamedToolChoiceType.function,
            function: ChatCompletionFunctionCallOption(name: function.name),
          ),
        ),
      );
      final res1 = await client.createChatCompletion(request: request1);
      expect(res1.choices, hasLength(1));

      final choice1 = res1.choices.first;

      final aiMessage1 = choice1.message;
      expect(aiMessage1.role, ChatCompletionMessageRole.assistant);
      expect(aiMessage1.content, isNull);
      expect(aiMessage1.toolCalls, hasLength(1));

      final toolCall = aiMessage1.toolCalls!.first;
      final functionCall = toolCall.function;
      expect(functionCall.name, function.name);
      expect(functionCall.arguments, isNotEmpty);
      final arguments = json.decode(
        functionCall.arguments,
      ) as Map<String, dynamic>;
      expect(arguments.containsKey('location'), isTrue);
      expect(arguments['location'], contains('Boston'));

      final functionResult = {
        'temperature': '22',
        'unit': 'celsius',
        'description': 'Sunny',
      };

      final request2 = CreateChatCompletionRequest(
        model: const ChatCompletionModel.model(
          ChatCompletionModels.gpt4oMini,
        ),
        messages: [
          const ChatCompletionMessage.system(
            content: 'You are a helpful assistant.',
          ),
          const ChatCompletionMessage.user(
            content: ChatCompletionUserMessageContent.string(
              'What’s the weather like in Boston right now?',
            ),
          ),
          aiMessage1,
          ChatCompletionMessage.tool(
            toolCallId: toolCall.id,
            content: json.encode(functionResult),
          ),
        ],
        tools: [tool],
      );
      final res2 = await client.createChatCompletion(request: request2);
      expect(res2.choices, hasLength(1));

      final choice2 = res2.choices.first;
      expect(choice2.finishReason, ChatCompletionFinishReason.stop);

      final aiMessage2 = choice2.message;
      expect(aiMessage2.role, ChatCompletionMessageRole.assistant);
      expect(aiMessage2.content, contains('22'));
      expect(aiMessage2.toolCalls, isNull);
      expect(aiMessage2.functionCall, isNull);
    });

    test('Test call chat completions API tools streaming', () async {
      const function = FunctionObject(
        name: 'joke',
        description: 'A joke',
        parameters: {
          'type': 'object',
          'properties': {
            'setup': {
              'type': 'string',
              'description': 'The setup for the joke',
            },
            'punchline': {
              'type': 'string',
              'description': 'The punchline to the joke',
            },
          },
          'required': ['location', 'punchline'],
        },
      );
      const tool = ChatCompletionTool(
        type: ChatCompletionToolType.function,
        function: function,
      );

      final request1 = CreateChatCompletionRequest(
        model: const ChatCompletionModel.model(
          ChatCompletionModels.gpt4oMini,
        ),
        messages: [
          const ChatCompletionMessage.system(
            content: 'You are a helpful assistant.',
          ),
          const ChatCompletionMessage.user(
            content: ChatCompletionUserMessageContent.string(
              'Tell me a long joke about bears',
            ),
          ),
        ],
        tools: [tool],
        toolChoice: ChatCompletionToolChoiceOption.tool(
          ChatCompletionNamedToolChoice(
            type: ChatCompletionNamedToolChoiceType.function,
            function: ChatCompletionFunctionCallOption(name: function.name),
          ),
        ),
      );
      final stream = client.createChatCompletionStream(request: request1);

      int count = 0;
      await for (final res in stream) {
        expect(res.id, isNotEmpty);
        expect(res.created, greaterThan(0));
        expect(
          res.object,
          isNotEmpty,
        );
        expect(res.model, startsWith('gpt-4o-mini'));
        expect(res.choices, hasLength(1));
        final choice = res.choices.first;
        expect(choice.index, 0);
        final delta = choice.delta;
        if (choice.finishReason != ChatCompletionFinishReason.stop) {
          expect(delta.toolCalls, hasLength(1), reason: 'count: $count');
          final toolCall = delta.toolCalls!.first;
          expect(toolCall.function, isNotNull);
          final function = toolCall.function!;
          if (count == 0) {
            expect(toolCall.id, isNotEmpty);
            expect(
              toolCall.type,
              ChatCompletionStreamMessageToolCallChunkType.function,
            );
            expect(function.name, 'joke');
          }
          expect(toolCall.index, 0);
          expect(function.arguments, isNotNull);
        }
        count++;
      }
      expect(count, greaterThan(1));
    });

    test('Test jsonObject response format', () async {
      const request = CreateChatCompletionRequest(
        model: ChatCompletionModel.model(
          ChatCompletionModels.gpt4oMini,
        ),
        messages: [
          ChatCompletionMessage.system(
            content:
                'You are a helpful assistant that extracts names from text '
                'and returns them in a JSON array.',
          ),
          ChatCompletionMessage.user(
            content: ChatCompletionUserMessageContent.string(
              'John, Mary, and Peter.',
            ),
          ),
        ],
        temperature: 0,
        responseFormat: ResponseFormat.jsonObject(),
      );
      final res = await client.createChatCompletion(request: request);
      expect(res.choices, hasLength(1));
      final choice = res.choices.first;
      final message = choice.message;
      expect(message.role, ChatCompletionMessageRole.assistant);
      final content = message.content;
      final jsonContent = json.decode(content!) as Map<String, dynamic>;
      final jsonName = jsonContent['names'] as List<dynamic>;
      expect(jsonName, isList);
      expect(jsonName, hasLength(3));
      expect(jsonName, contains('John'));
      expect(jsonName, contains('Mary'));
      expect(jsonName, contains('Peter'));
    });

    test('Test jsonSchema response format', () async {
      const request = CreateChatCompletionRequest(
        model: ChatCompletionModel.model(
          ChatCompletionModels.gpt4oMini,
        ),
        messages: [
          ChatCompletionMessage.system(
            content:
                'You are a helpful assistant. That extracts names from text.',
          ),
          ChatCompletionMessage.user(
            content: ChatCompletionUserMessageContent.string(
              'John, Mary, and Peter.',
            ),
          ),
        ],
        temperature: 0,
        responseFormat: ResponseFormat.jsonSchema(
          jsonSchema: JsonSchemaObject(
            name: 'Names',
            description: 'A list of names',
            strict: true,
            schema: {
              'type': 'object',
              'properties': {
                'names': {
                  'type': 'array',
                  'items': {
                    'type': 'string',
                  },
                },
              },
              'additionalProperties': false,
              'required': ['names'],
            },
          ),
        ),
      );
      final res = await client.createChatCompletion(request: request);
      expect(res.choices, hasLength(1));
      final choice = res.choices.first;
      final message = choice.message;
      expect(message.role, ChatCompletionMessageRole.assistant);
      final content = message.content;
      final jsonContent = json.decode(content!) as Map<String, dynamic>;
      final jsonName = jsonContent['names'] as List<dynamic>;
      expect(jsonName, isList);
      expect(jsonName, hasLength(3));
      expect(jsonName, contains('John'));
      expect(jsonName, contains('Mary'));
      expect(jsonName, contains('Peter'));
    });

    test('Test response seed', () async {
      const request = CreateChatCompletionRequest(
        model: ChatCompletionModel.model(
          ChatCompletionModels.gpt4TurboPreview,
        ),
        messages: [
          ChatCompletionMessage.system(
            content: 'You are a helpful assistant.',
          ),
          ChatCompletionMessage.user(
            content: ChatCompletionUserMessageContent.string('How are you?'),
          ),
        ],
        temperature: 0,
        seed: 9999999999,
      );
      final res1 = await client.createChatCompletion(request: request);
      expect(res1.choices, hasLength(1));
      final choice1 = res1.choices.first;

      final res2 = await client.createChatCompletion(request: request);
      expect(res2.choices, hasLength(1));
      final choice2 = res2.choices.first;

      expect(res1.systemFingerprint, res2.systemFingerprint);
      expect(choice1.message.content, choice2.message.content);
    });

    test('Test multi-modal GPT-4 Vision', () async {
      const request = CreateChatCompletionRequest(
        model: ChatCompletionModel.model(
          ChatCompletionModels.gpt4VisionPreview,
        ),
        messages: [
          ChatCompletionMessage.system(
            content: 'You are a helpful assistant.',
          ),
          ChatCompletionMessage.user(
            content: ChatCompletionUserMessageContent.parts(
              [
                ChatCompletionMessageContentPart.text(
                  text: 'What fruit is this?',
                ),
                ChatCompletionMessageContentPart.image(
                  imageUrl: ChatCompletionMessageImageUrl(
                    url:
                        'https://upload.wikimedia.org/wikipedia/commons/9/92/95apple.jpeg',
                  ),
                ),
                ChatCompletionMessageContentPart.video(
                  videoUrl: ChatCompletionMessageVideoUrl(
                    url:
                        'https://ff50112422257af23f6bb0f9d26763a89477edb018250f9db3b1f5d-apidata.googleusercontent.com/download/storage/v1/b/ttd-dev-3a8f0.firebasestorage.app/o/feedback_video%2Fimagepicker4b946077b16d42e3851a484d50de8a85558130000046e9e8017b8trim_f6304d90-edbc-11ef-85d4-e7458b842634.MOV?jk=AVyuY3jBSCblQdtRLdpxLgnW0zn3I5JHQPw-0qPc21wsXpFq9cjz2rgfb7nepTjDZua0Ejj_d4z8qSmKJ0MzwBbNt3FSwBAH8muXiLhKda0tVfhIdTztWj1qBlx3SX1B15AsD6s7k9PXAaodwQjnEsU_0GUjIrLgOCHQCa0IExDsPorT8psru8psEfRLgZs2E0mTlODp1v4Ib_QGlDOhVrWmoipB602pJqBeWy_vvA3uGUcifhTBYd9Wxfe93Oj8M-sqSXN_j8ADe4OfRnnw9QSrathaadJSL6XTvZIJq9Ri7OTiQ4GOsLxgkHXaemXwH9Iz-0_MFt_eCBYSNzZw-LS0uH5dQ274nl1wcYm3IckJ4IN1dSE7qq5I6t_7RwnnXwoL1EACpD4beUDBcnDHnSWbKn66eSfHvSKBtzOAZe3_bxPmQemNyOqTajpHp9LDP6WTBfDZAa5FsYgEqsrpZRTe0NmJXMJneqm_196ubk_dua3w8hXdtg_ALnqt2p2IQyUyq-u8MnHTDkZFzpwJnCRb8T55vZo4d5SGZncdKX4MlF7SRGtE29Axo2tgrPHTNh2iwEMAdFrackqbLYAvGkJinO6W5KaNVEEC6vi8lMUNzLM1rZl6RNF641QulYh7ukVYg0MK-MPDdsbt8k9Is0DekwAQJsw2t9IiOIQkX0_Hh5yuDeU3w5b1lgBO0IbcQkQ4AyM-FmI9buXbS7LC79pIZs3sP34ZlOWK8G6V4POf07rg3tookltCmkbYEgYKGwkQ6PSR_5Dhx5mGcCQJV43ftdyBrpi01wSNx5WVqoav0t_3WHUrurqCnpe0lD9sC5mKijBp6QTW5F7YEacNqvWljbHiD4mFIXPtHiKbDn00Xiua1NTrs00SabOtHAd-FMQmxB0v0WucsVHYlz1CQP8PjKu4qMC0KMUV2fNEXDHMlT6cbp93mZmtfSApq5GPnln4YgQQCc5iO3lCbMtRNeceK6yPsR-h8Jl5zXH0kgmUzpkNv256cS5EeE_Ia1KGElGQDQ1GEsbmaRSxPVn0-8r0Jk8iL0E599KAHnRNXHCrjgth87wb28DsTAmgTZ5QEmY9tulD2YN3VS9jWJ6ufo6pV09HsrLVkR9_vvixH5qrw2HJdWedssbiOSWKVE4MoFUZIFg4dfv04VZlY1Z69OtIel3t9ijxvugHE7mka2HDAOaZUnYvKp_1MlMLTRCpVR4qnNxIarGdczdWP29Jn7uiJMmt1sPG0dFmZgIfZm_ARW0kr4cxkOZA7W-5auggxOo3ZaHhQCnVgJ_SNfV4nkzHUS2EK-Ssu2xTyZs&isca=1',
                  ),
                ),
              ],
            ),
          ),
        ],
      );
      final res1 = await client.createChatCompletion(request: request);
      expect(res1.choices, hasLength(1));
      final choice1 = res1.choices.first;
      expect(choice1.message.content?.toLowerCase(), contains('apple'));
    });
  });
}
