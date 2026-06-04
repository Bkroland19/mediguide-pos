import 'package:get/get.dart';
import 'package:openai_dart/openai_dart.dart';
import '../../utils/constants.dart';
import '../../utils/common.dart';

/// Service for handling the optional assistant feature
/// Follows GetX service patterns with proper async initialization
class OpenAiService extends GetxService {
  static OpenAiService get to => Get.find();

  OpenAIClient? _client;
  bool get isConfigured => openRouterApiKey.trim().isNotEmpty;

  /// Initialize the service with proper async pattern
  Future<OpenAiService> init() async {
    try {
      if (isConfigured) {
        _client = OpenAIClient(
          apiKey: openRouterApiKey,
          baseUrl: openRouterBaseUrl,
        );
      }
      return this;
    } catch (e) {
      Common.quickToast(
        title: 'AI Service Error',
        description: 'Failed to initialize AI assistant: ${e.toString()}',
      );
      rethrow;
    }
  }

  String get _defaultInstructions => '''
Provide concise, medically cautious answers.
Use available application context when relevant.
State clearly when more clinical judgment or urgent in-person care is needed.
''';

  /// Create a chat completion with medical context
  Future<String> createChatCompletion({
    required String userMessage,
    List<String>? conversationHistory,
    String? customInstructions,
  }) async {
    try {
      if (!isConfigured || _client == null) {
        return _getFallbackResponse(userMessage);
      }

      // Build conversation messages
      final messages = <ChatCompletionMessage>[
        ChatCompletionMessage.system(content: customInstructions ?? _defaultInstructions),
        
        // Add conversation history if provided
        if (conversationHistory != null)
          ...conversationHistory.asMap().entries.map((entry) {
            final isUser = entry.key % 2 == 0;
            return isUser 
              ? ChatCompletionMessage.user(content: ChatCompletionUserMessageContent.string(entry.value))
              : ChatCompletionMessage.assistant(content: entry.value);
          }),
        
        // Add current user message
        ChatCompletionMessage.user(content: ChatCompletionUserMessageContent.string(userMessage)),
      ];

      final response = await _client!.createChatCompletion(
        request: CreateChatCompletionRequest(
          model: ChatCompletionModel.modelId(openRouterModel),
          messages: messages,
          maxTokens: 500,
          temperature: 0.7,
          topP: 1.0,
        ),
      );

      final content = response.choices.first.message.content;
      if (content == null || content.isEmpty) {
        throw Exception('Empty response from AI service');
      }

      return content;
    } catch (e) {
      Common.quickToast(
        title: 'AI Response Error',
        description: 'Failed to get AI response: ${e.toString()}',
      );
      return _getFallbackResponse(userMessage);
    }
  }


  /// Get fallback response when AI service fails
  String _getFallbackResponse(String userMessage) {
    final lowerMessage = userMessage.toLowerCase();
    final notConfigured = !isConfigured;
    
    if (lowerMessage.contains('emergency') || lowerMessage.contains('urgent')) {
      return '''
🚨 **MEDICAL EMERGENCY**

If this is a life-threatening emergency, please:
1. Call emergency services immediately
2. Seek immediate medical attention
3. Contact the nearest healthcare facility

MediGuide AI is currently ${notConfigured ? 'not configured for this build' : 'unavailable'}, but you can:
• Browse our Guidelines section for clinical protocols
• Check the Drug Index for medication information
• Use our medical calculators in Tools section
• Connect with Consultants for expert advice

**Disclaimer**: This is not a substitute for emergency medical care.
''';
    }
    
    if (lowerMessage.contains('drug') || lowerMessage.contains('medicine')) {
      return '''
💊 **Drug Information**

MediGuide AI is temporarily ${notConfigured ? 'not configured in this environment' : 'unavailable'}. For medication information:

• **Drug Index**: Browse our comprehensive drug database
• **Interactions**: Check drug interactions and contraindications
• **Dosages**: Reference dosing guidelines and calculations
• **Side Effects**: Review adverse reactions and monitoring

Navigate to the Drug Index section or consult with our medical experts.
''';
    }
    
    if (lowerMessage.contains('guideline') || lowerMessage.contains('protocol')) {
      return '''
📋 **Clinical Guidelines**

MediGuide AI is temporarily ${notConfigured ? 'not configured in this environment' : 'unavailable'}. For clinical guidance:

• **Guidelines Section**: Access evidence-based treatment protocols
• **Clinical Pathways**: Follow standardized care procedures
• **Best Practices**: Review recommended clinical approaches
• **Updates**: Check for latest guideline revisions

Navigate to the Guidelines section for comprehensive protocols.
''';
    }
    
      return '''
🤖 **MediGuide AI ${notConfigured ? 'Not Configured' : 'Temporarily Unavailable'}**

${notConfigured ? 'This build does not include an OpenRouter API key, so the AI assistant is disabled.' : 'The AI assistant is currently experiencing difficulties.'}

**Available Resources:**
• **Drug Index**: Comprehensive medication information
• **Guidelines**: Clinical treatment protocols
• **Tools**: Medical calculators and decision aids  
• **Consultants**: Connect with medical experts

**For urgent medical questions**: Please consult with healthcare professionals or use our Consultants feature.

**Disclaimer**: Always verify information with qualified healthcare providers.
''';
  }

  /// Get contextual suggestions based on user query
  List<String> getContextualSuggestions(String userMessage) {
    final lowerMessage = userMessage.toLowerCase();
    
    if (lowerMessage.contains('drug') || lowerMessage.contains('medicine')) {
      return [
        'Check drug interactions',
        'View dosing guidelines',
        'Browse Drug Index',
        'Calculate pediatric doses',
      ];
    }
    
    if (lowerMessage.contains('guideline') || lowerMessage.contains('protocol')) {
      return [
        'Search treatment guidelines',
        'View emergency protocols',
        'Access clinical pathways',
        'Check latest updates',
      ];
    }
    
    if (lowerMessage.contains('calculator') || lowerMessage.contains('tool')) {
      return [
        'BMI calculator',
        'Dosage calculator',
        'Risk assessment tools',
        'Clinical checklists',
      ];
    }
    
    return [
      'Search medical guidelines',
      'Check drug information',
      'Use medical calculators',
      'Consult with experts',
    ];
  }

}
