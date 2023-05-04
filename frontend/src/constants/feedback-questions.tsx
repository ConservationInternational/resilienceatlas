import { FeedbackFieldTypes } from 'types/wizard-form.d';
import { t } from '@transifex/native';

const getLocationsList = () => [
  { id: 'africa', label: t('Africa') },
  { id: 'asia', label: t('Asia') },
  { id: 'caribbean', label: t('Caribbean') },
  { id: 'central_america', label: t('Central America') },
  { id: 'eastern_europe', label: t('Eastern Europe') },
  { id: 'european_union', label: t('European Union') },
  { id: 'middle_east', label: t('Middle East') },
  { id: 'north_america', label: t('North America') },
  { id: 'oceania', label: t('Oceania') },
  { id: 'south_america', label: t('South America') },
  { id: 'uk', label: t('UK') },
];

export const getIntro = () => ({
  title: t('Intro'),
  nextButton: t('Tool Use'),
  questions: [
    {
      id: 'work_sector',
      type: FeedbackFieldTypes.Single,
      required: true,
      question: t('What sector do you work in?'),
      answers: [
        { id: 'government', label: t('Government') },
        { id: 'academia', label: t('Academia') },
        { id: 'non_profit', label: t('Non-profit') },
        { id: 'private', label: t('Private') },
        { id: 'donor', label: t('Donor') },
        { id: 'media', label: t('Media') },
      ],
      customAnswer: {
        id: 'work_sector_other',
        label: t('Other:'),
      },
    },
    {
      id: 'gender',
      type: FeedbackFieldTypes.Single,
      required: true,
      question: t('What is your gender?'),
      description: t('This question helps us to report on _____ goals.'),
      answers: [
        { id: 'female', label: t('Female') },
        { id: 'male', label: t('Male') },
        { id: 'transgender', label: t('Transgender') },
        { id: 'non_binary', label: t('Non-binary') },
        { id: 'no_answer', label: t('Prefer not to answer') },
      ],
      customAnswer: {
        id: 'gender_other',
        label: t('Other:'),
      },
    },
    {
      id: 'location',
      type: FeedbackFieldTypes.Single,
      required: true,
      question: t('Where are you located?'),
      answers: getLocationsList(),
      customAnswer: {
        id: 'intro_location_other',
        label: t('Other:'),
      },
    },
    {
      id: 'projects_locations',
      type: FeedbackFieldTypes.Multiple,
      required: true,
      question: t('Where are your project(s) located?'),
      answers: getLocationsList(),
      customAnswer: {
        id: 'intro_projects_location_other',
        label: t('Other:'),
      },
    },
    {
      id: 'how_did_you_find',
      type: FeedbackFieldTypes.Multiple,
      question: t('How did you find out about the Resilience Atlas?'),
      answers: [
        { id: 'internet_search', label: t('Internet search') },
        { id: 'colleagues_word_of_mouth', label: t('Colleagues/word-of-mouth') },
        { id: 'social_media', label: t('Social media (twitter, facebook)') },
        { id: 'peer_reviewed_publication', label: t('Peer-reviewed publication') },
        {
          id: 'conservation_international',
          label: t('Conservation International webinar/workshop/training'),
        },
        { id: 'dont_remember', label: t("Don't recall") },
      ],
      customAnswer: {
        id: 'how_did_you_find_other',
        label: t('Other:'),
      },
    },
  ],
});

export const getToolUse = () => ({
  title: t('Tool Use'),
  previousButton: t('Intro'),
  nextButton: t('Map'),
  questions: [
    {
      id: 'usage',
      type: FeedbackFieldTypes.Single,
      required: true,
      question: t('What are you using the Resilience Atlas for?'),
      answers: [
        { id: 'conduct_research', label: t('Conduct research') },
        { id: 'design_and_or_inform', label: t('Design and/or inform policy') },
        { id: 'inform_conservation', label: t('Inform conservation or land management decisions') },
        {
          id: 'inform_prioritize_investiments',
          label: t('Inform/prioritize investment decisions'),
        },
        {
          id: 'prioritize-¡_adaptation',
          label: t('Prioritize adaptation & sustainable development interventions'),
        },
        { id: 'inform_advocacy', label: t('Inform advocacy') },
        { id: 'inform_journalism', label: t('Inform journalism') },
        { id: 'have_not_used', label: t('I have not used the Resilience Atlas') },
      ],
      customAnswer: {
        id: 'usage_other',
        label: t('Other:'),
      },
    },
    {
      id: 'usage_projects',
      type: FeedbackFieldTypes.FreeAnswer,
      question: t('Briefly explain the project(s) that you have used the Resilience Atlas for:'),
    },
  ],
});

export const getMap = () => ({
  title: t('Map'),
  previousButton: t('Tool Use'),
  nextButton: t('Website'),
  questions: [
    {
      id: 'map_rating',
      type: FeedbackFieldTypes.Rating,
      question: t(
        'Please rate the following on a scale of 1 (strongly disagree) to 5 (strongly agree):',
      ),
      answers: [
        {
          id: 'understood_different_datasets',
          label: t('I understood what the different datasets represented'),
        },
        {
          id: 'able_to_find_datasets',
          label: t('I was able to find the dataset(s) I was looking for'),
        },
        {
          id: 'able_to_get_results',
          label: t('I was able to get the results that I wanted'),
        },
        {
          id: 'mapping_tool_as_expected',
          label: t('The mapping tool worked as I expected it to'),
        },
      ],
    },
    {
      id: 'map_useful_features',
      type: FeedbackFieldTypes.Multiple,
      question: t('What features of the Resilience Atlas are most useful?'),
      answers: [
        { id: 'diverse_datasets', label: t('Diverse datasets in one location') },
        { id: 'access_datasets', label: t('Access to new datasets') },
        { id: 'web_platform', label: t('Web-based platform') },
        { id: 'journeys', label: t('Journeys') },
        { id: 'multiple_layers', label: t('Overlaying multiple layers') },
        {
          id: 'interactivity',
          label:
            'Interactivity - turning layers on and off, reordering layers, changing transparency',
        },
        { id: 'data_download', label: t('Data download') },
      ],
      customAnswer: {
        id: 'map_useful_features_other',
        label: t('Other:'),
      },
    },
    {
      id: 'useful_features',
      type: FeedbackFieldTypes.FreeAnswer,
      question: t('Why were these features particularly useful to you?'),
    },
    {
      id: 'coming_back_features',
      type: FeedbackFieldTypes.Multiple,
      question: t('What features have made you come back to the Resilience Atlas?'),
      answers: [
        { id: 'diverse_datasets', label: t('Diverse datasets in one location') },
        { id: 'new_datasets', label: t('Access to new datasets') },
        { id: 'web_platform', label: t('Web-based platform') },
        { id: 'journeys', label: t('Journeys') },
        { id: 'multiple_layers', label: t('Overlaying multiple layers') },
        {
          id: 'interactivity',
          label:
            'Interactivity - turning layers on and off, reordering layers, changing transparency',
        },
        { id: 'data_download', label: t('Data download') },
        { id: 'data_analysis', label: t('Data analysis') },
        { id: 'data_download_report', label: t('Download PDF report of data analysis') },
      ],
      customAnswer: {
        id: 'coming_back_features_other',
        label: t('Other:'),
      },
    },
    {
      id: 'usefulness_feedback',
      type: FeedbackFieldTypes.Multiple,
      question: t('What would make the Resilience Atlas more useful?'),
      description: t(
        'Please write additional ideas under "other", and expand on them in the box below.',
      ),
      answers: [
        {
          id: 'increased_data_visualization',
          label: t('Increased data visualization functionality'),
        },
        { id: 'customizable_reports', label: t('Customizable PDF report') },
        { id: 'save_maps', label: t('Ability to save maps when logged in') },
      ],
      customAnswer: {
        id: 'usefulness_feedback_other',
        label: t('Other:'),
      },
    },
    {
      id: 'new_feature_suggestion',
      type: FeedbackFieldTypes.FreeAnswer,
      question: t('If you suggested a new feature, please describe it further:'),
    },
    {
      id: 'new_feature_suggestion_explanation',
      type: FeedbackFieldTypes.FreeAnswer,
      question: t('Why would these new features be useful to you?'),
    },
  ],
});

export const getWebsite = () => ({
  title: t('Website'),
  previousButton: t('Map'),
  questions: [
    {
      id: 'website_rating',
      type: FeedbackFieldTypes.Rating,
      question: t(
        'Please rate the following on a scale of 1 (strongly disagree) to 5 (strongly agree):',
      ),
      answers: [
        {
          id: 'ease_of_navigation',
          label: t('It was easy to navigate the website'),
        },
        {
          id: 'found_information',
          label: t('I found the information that I needed'),
        },
        {
          id: 'tool_use_clear',
          label: t('It was clear how the tool should be used'),
        },
      ],
    },
    {
      id: 'website_usefulness',
      type: FeedbackFieldTypes.Multiple,
      question: t('What parts of the Resilience Atlas website were useful for your work?'),
      answers: [
        { id: 'journeys', label: t('Journeys') },
        { id: 'map', label: t('Map') },
        { id: 'about', label: t('About') },
      ],
    },
    {
      id: 'would_you_recommend',
      type: FeedbackFieldTypes.Boolean,
      question: t('Would you recommend the Resilience Atlas to a colleague?'),
      answers: [
        {
          id: 'yes',
          label: t('Yes'),
          value: true,
        },
        {
          id: 'no',
          label: t('No'),
          value: false,
        },
      ],
    },
    {
      id: 'recommendation_explanation',
      type: FeedbackFieldTypes.FreeAnswer,
      question: t('Why or why not?'),
    },
    {
      id: 'thoughts',
      type: FeedbackFieldTypes.FreeAnswer,
      question: t('Is there anything else you want to say about the Resilience Atlas?'),
    },
    {
      id: 'accepts_contact',
      type: FeedbackFieldTypes.FreeAnswer,
      question: t(
        "If you're willing to be contacted about your answers, please leave your email address:",
      ),
    },
  ],
});
