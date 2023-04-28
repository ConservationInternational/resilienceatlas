import { FeedbackFieldTypes } from 'types/wizard-form.d';

const LOCATIONS_LIST = [
  { id: 'africa', label: 'Africa' },
  { id: 'asia', label: 'Asia' },
  { id: 'caribbean', label: 'Caribbean' },
  { id: 'central_america', label: 'Central America' },
  { id: 'eastern_europe', label: 'Eastern Europe' },
  { id: 'european_union', label: 'European Union' },
  { id: 'middle_east', label: 'Middle East' },
  { id: 'north_america', label: 'North America' },
  { id: 'oceania', label: 'Oceania' },
  { id: 'south_america', label: 'South America' },
  { id: 'uk', label: 'UK' },
];

export const INTRO = {
  title: 'Intro',
  nextButton: 'Tool Use',
  questions: [
    {
      id: 'work_sector',
      type: FeedbackFieldTypes.Single,
      required: true,
      question: 'What sector do you work in?',
      answers: [
        { id: 'government', label: 'Government' },
        { id: 'academia', label: 'Academia' },
        { id: 'non_profit', label: 'Non-profit' },
        { id: 'private', label: 'Private' },
        { id: 'donor', label: 'Donor' },
        { id: 'media', label: 'Media' },
      ],
      customAnswer: {
        id: 'work_sector_other',
        label: 'Other',
      },
    },
    {
      id: 'gender',
      type: FeedbackFieldTypes.Single,
      required: true,
      question: 'What is your gender?',
      description: 'This question helps us to report on _____ goals.',
      answers: [
        { id: 'female', label: 'Female' },
        { id: 'male', label: 'Male' },
        { id: 'transgender', label: 'Transgender' },
        { id: 'non_binary', label: 'Non-binary' },
        { id: 'no_answer', label: 'Prefer not to answer' },
      ],
      customAnswer: {
        id: 'gender_other',
        label: 'Other',
      },
    },
    {
      id: 'location',
      type: FeedbackFieldTypes.Single,
      required: true,
      question: 'Where are you located?',
      answers: LOCATIONS_LIST,
      customAnswer: {
        id: 'intro_location_other',
        label: 'Other',
      },
    },
    {
      id: 'projects_locations',
      type: FeedbackFieldTypes.Multiple,
      required: true,
      question: 'Where are your project(s) located?',
      answers: LOCATIONS_LIST,
      customAnswer: {
        id: 'intro_projects_location_other',
        label: 'Other',
      },
    },
    {
      id: 'how_did_you_find',
      type: FeedbackFieldTypes.Multiple,
      question: 'How did you find out about the Resilience Atlas?',
      answers: [
        { id: 'internet_search', label: 'Internet search' },
        { id: 'colleagues_word_of_mouth', label: 'Colleagues/word-of-mouth' },
        { id: 'social_media', label: 'Social media (twitter, facebook)' },
        { id: 'peer_reviewed_publication', label: 'Peer-reviewed publication' },
        {
          id: 'conservation_international',
          label: 'Conservation International webinar/workshop/training',
        },
        { id: 'dont_remember', label: "Don't recall" },
      ],
      customAnswer: {
        id: 'how_did_you_find_other',
        label: 'Other',
      },
    },
  ],
};

export const TOOL_USE = {
  title: 'Tool Use',
  previousButton: 'Intro',
  nextButton: 'Map',
  questions: [
    {
      id: 'usage',
      type: FeedbackFieldTypes.Single,
      required: true,
      question: 'What are you using the Resilience Atlas for?',
      answers: [
        { id: 'conduct_research', label: 'Conduct research' },
        { id: 'design_and_or_inform', label: 'Design and/or inform policy' },
        { id: 'inform_conservation', label: 'Inform conservation or land management decisions' },
        { id: 'inform_prioritize_investiments', label: 'Inform/prioritize investment decisions' },
        {
          id: 'prioritize-¡_adaptation',
          label: 'Prioritize adaptation & sustainable development interventions',
        },
        { id: 'inform_advocacy', label: 'Inform advocacy' },
        { id: 'inform_journalism', label: 'Inform journalism' },
        { id: 'have_not_used', label: 'I have not used the Resilience Atlas' },
      ],
      customAnswer: {
        id: 'usage_other',
        label: 'Other',
      },
    },
    {
      id: 'usage_projects',
      type: FeedbackFieldTypes.FreeAnswer,
      question: 'Briefly explain the project(s) that you have used the Resilience Atlas for:',
    },
  ],
};

export const MAP = {
  title: 'Map',
  previousButton: 'Tool Use',
  nextButton: 'Website',
  questions: [
    {
      id: 'map_rating',
      type: FeedbackFieldTypes.Rating,
      question:
        'Please rate the following on a scale of 1 (strongly disagree) to 5 (strongly agree):',
      answers: [
        {
          id: 'understood_different_datasets',
          label: 'I understood what the different datasets represented',
        },
        {
          id: 'able_to_find_datasets',
          label: 'I was able to find the dataset(s) I was looking for',
        },
        {
          id: 'able_to_get_results',
          label: 'I was able to get the results that I wanted',
        },
        {
          id: 'mapping_tool_as_expected',
          label: 'The mapping tool worked as I expected it to',
        },
      ],
    },
    {
      id: 'map_useful_features',
      type: FeedbackFieldTypes.Multiple,
      question: 'What features of the Resilience Atlas are most useful?',
      answers: [
        { id: 'diverse_datasets', label: 'Diverse datasets in one location' },
        { id: 'access_datasets', label: 'Access to new datasets' },
        { id: 'web_platform', label: 'Web-based platform' },
        { id: 'journeys', label: 'Journeys' },
        { id: 'multiple_layers', label: 'Overlaying multiple layers' },
        {
          id: 'interactivity',
          label:
            'Interactivity - turning layers on and off, reordering layers, changing transparency',
        },
        { id: 'data_download', label: 'Data download' },
      ],
      customAnswer: {
        id: 'map_useful_features_other',
        label: 'Other',
      },
    },
    {
      id: 'useful_features',
      type: FeedbackFieldTypes.FreeAnswer,
      question: 'Why were these features particularly useful to you?',
    },
    {
      id: 'coming_back_features',
      type: FeedbackFieldTypes.Multiple,
      question: 'What features have made you come back to the Resilience Atlas?',
      answers: [
        { id: 'diverse_datasets', label: 'Diverse datasets in one location' },
        { id: 'new_datasets', label: 'Access to new datasets' },
        { id: 'web_platform', label: 'Web-based platform' },
        { id: 'journeys', label: 'Journeys' },
        { id: 'multiple_layers', label: 'Overlaying multiple layers' },
        {
          id: 'interactivity',
          label:
            'Interactivity - turning layers on and off, reordering layers, changing transparency',
        },
        { id: 'data_download', label: 'Data download' },
        { id: 'data_analysis', label: 'Data analysis' },
        { id: 'data_download_report', label: 'Download PDF report of data analysis' },
      ],
      customAnswer: {
        id: 'coming_back_features_other',
        label: 'Other',
      },
    },
    {
      id: 'usefulness-feedback',
      type: FeedbackFieldTypes.Multiple,
      question: 'What would make the Resilience Atlas more useful?',
      description:
        'Please write additional ideas under "other", and expand on them in the box below.',
      answers: [
        {
          id: 'increased_data_visualization',
          label: 'Increased data visualization functionality',
        },
        { id: 'customizable_reports', label: 'Customizable PDF report' },
        { id: 'save_maps', label: 'Ability to save maps when logged in' },
        { id: 'usefulness_feedback_other', label: 'Other:' },
      ],
    },
    {
      id: 'new_feature_suggestion',
      type: FeedbackFieldTypes.FreeAnswer,
      question: 'If you suggested a new feature, please describe it further:',
    },
    {
      id: 'new_feature_suggestion_explanation',
      type: FeedbackFieldTypes.FreeAnswer,
      question: 'Why would these new features be useful to you?',
    },
  ],
};

export const WEBSITE = {
  title: 'Website',
  previousButton: 'Map',
  questions: [
    {
      id: 'website_rating',
      type: FeedbackFieldTypes.Rating,
      question:
        'Please rate the following on a scale of 1 (strongly disagree) to 5 (strongly agree):',
      answers: [
        {
          id: 'ease_of_navigation',
          label: 'It was easy to navigate the website',
        },
        {
          id: 'found_information',
          label: 'I found the information that I needed',
        },
        {
          id: 'tool_use_clear',
          label: 'It was clear how the tool should be used',
        },
      ],
    },
    {
      id: 'website_usefulness',
      type: FeedbackFieldTypes.Multiple,
      question: 'What parts of the Resilience Atlas website were useful for your work?',
      answers: [
        { id: 'journeys', label: 'Journeys' },
        { id: 'map', label: 'Map' },
        { id: 'about', label: 'About' },
      ],
    },
    {
      id: 'would_you_recommend',
      type: FeedbackFieldTypes.Boolean,
      question: 'Would you recommend the Resilience Atlas to a colleague?',
      answers: [
        {
          id: 'yes',
          label: 'Yes',
          value: true,
        },
        {
          id: 'no',
          label: 'No',
          value: false,
        },
      ],
    },
    {
      id: 'recommendation_explanation',
      type: FeedbackFieldTypes.FreeAnswer,
      question: 'Why or why not?',
    },
    {
      id: 'thoughts',
      type: FeedbackFieldTypes.FreeAnswer,
      question: 'Is there anything else you want to say about the Resilience Atlas?',
    },
    {
      id: 'accepts_contact',
      type: FeedbackFieldTypes.FreeAnswer,
      question:
        "If you're willing to be contacted about your answers, please leave your email address:",
    },
  ],
};
