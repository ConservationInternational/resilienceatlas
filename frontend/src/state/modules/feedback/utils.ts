import * as Yup from 'yup';
import flatten from 'lodash/flatten';
import uniqBy from 'lodash/uniqBy';

import { FeedbackFieldTypes } from 'types/wizard-form.d';
import { INTRO, TOOL_USE, MAP, WEBSITE } from 'constants/feedback-questions';

// VALIDATION

const VALIDATION_ERRORS = {
  required: 'This is a required question',
};

export const IntroSchema = Yup.object().shape({
  work_sector: Yup.string().required(VALIDATION_ERRORS.required),
  work_sector_other: Yup.string().when('work_sector', {
    is: (val: string) => val === 'work_sector_other',
    then: (schema) => schema.required(VALIDATION_ERRORS.required),
  }),
  gender: Yup.string().required(VALIDATION_ERRORS.required),
  gender_other: Yup.string().when('gender', {
    is: (val: string) => val === 'gender_other',
    then: (schema) => schema.required(VALIDATION_ERRORS.required),
  }),
  location: Yup.string().required(VALIDATION_ERRORS.required),
  intro_location_other: Yup.string().when('location', {
    is: (val: string) => val === 'intro_location_other',
    then: (schema) => schema.required(VALIDATION_ERRORS.required),
  }),
  projects_locations: Yup.array().required(VALIDATION_ERRORS.required),
  projects_locations_other: Yup.string().when('projects_locations', {
    is: (val: string) => val === 'projects_locations_other',
    then: (schema) => schema.required(VALIDATION_ERRORS.required),
  }),
});

export const ToolUseSchema = Yup.object().shape({
  usage: Yup.string().required(VALIDATION_ERRORS.required),
  usage_other: Yup.string().when('usage', {
    is: (val: string) => val === 'usage_other',
    then: (schema) => schema.required(VALIDATION_ERRORS.required),
  }),
});

export const MapSchema = Yup.object().shape({});

export const WebsiteSchema = Yup.object().shape({});

// FORM PROCESSING

export const processFeedbackForm = (formValues) => {
  let processedData = [];

  // Prepare questions and form values data in a way that's easier to process.
  const questionsData = flatten([INTRO, TOOL_USE, MAP, WEBSITE].map((item) => item.questions));
  const valuesData = Object.entries(formValues).map(([id, value]) => ({
    id,
    value,
  }));

  // Build attributes in a format the the API expects, for a particular question
  const buildAttributes = (question, answer = null) => {
    return {
      id: question.id,
      feedback_field_type: question.type,
      question: question.question,
      ...(answer && {
        answer: {
          value: answer,
        },
      }),
    };
  };

  // Process SINGLE | FEEDBACK FIELD TYPE
  const processSingle = (question) => {
    let answerData = null;

    const formAnswer = valuesData.find(({ id }) => question.id === id);
    if (!formAnswer) return;

    const answer = question.answers.find(({ id }) => id === formAnswer.value);
    if (answer) {
      answerData = buildAttributes(question, answer.label);
    }

    if (question.customAnswer) {
      const customAnswer = valuesData.find(({ id }) => id === question.customAnswer.id);
      if (customAnswer) {
        answerData = buildAttributes(question, customAnswer.value);
      }
    }

    if (answerData) {
      processedData.push(answerData);
    }
  };

  // Process MULTIPLE | FEEDBACK FIELD TYPE
  const processMultiple = (question) => {
    let answerData = null;

    const formAnswer = valuesData.find(({ id }) => question.id === id);
    if (!formAnswer) return;

    const formAnswerValues = (
      Array.isArray(formAnswer.value) ? formAnswer.value : [formAnswer.value]
    ) as string[];

    const answers = (formAnswerValues || [])
      .map((answer) => question.answers.find(({ id }) => id === answer)?.label)
      .filter((answer) => !!answer);

    if (answers.length) {
      answerData = buildAttributes(question, answers);
    }

    if (question.customAnswer) {
      const customAnswer = valuesData.find(({ id }) => id === question.customAnswer.id);

      if (customAnswer) {
        if (answers.length) {
          answerData?.answer?.value?.push(customAnswer.value);
        } else {
          answerData = buildAttributes(question, customAnswer.value);
        }
      }
    }

    if (answerData?.answer?.value?.length) {
      processedData.push(answerData);
    }
  };

  // Process BOOLEAN | FEEDBACK FIELD TYPE
  const processBoolean = (question) => {
    let answerData = null;

    const formAnswer = valuesData.find(({ id }) => question.id === id);
    if (!formAnswer) return;

    const answer = question.answers.find(
      (questionAnswer) => questionAnswer.value === formAnswer.value,
    );

    if (answer) {
      answerData = buildAttributes(question, answer.label);
    }

    if (answerData) {
      processedData.push(answerData);
    }
  };

  // Process FREE_ANSWER | FEEDBACK FIELD TYPE
  const processFreeAnswer = (question) => {
    let answerData = null;

    const answer = valuesData.find(({ id }) => id === question.id);

    if (answer) {
      answerData = buildAttributes(question, answer.value);
    }

    if (answerData) {
      processedData.push(answerData);
    }
  };

  // Process RATING | FEEDBACK FIELD TYPE
  const processRating = (question) => {
    let answerData = null;

    const formData = valuesData.find(({ id }) => id === question.id);
    if (!formData?.value) return;

    const formValues = Object.assign({}, ...(formData?.value as []));

    const answers = (question?.answers || [])
      .map((questionAnswer) => {
        const answer = formValues[questionAnswer.id];
        if (!answer) return null;
        return {
          feedback_field_type: FeedbackFieldTypes.Rating,
          question: questionAnswer.label,
          answer: {
            value: answer,
          },
        };
      })
      .filter((answer) => !!answer);

    if (answers.length) {
      answerData = {
        ...buildAttributes(question),
        children_attributes: answers,
      };
    }

    if (answerData) {
      processedData.push(answerData);
    }
  };

  // Iterate through the questions and process them
  questionsData.map((question) => {
    const { type } = question;

    switch (type) {
      case FeedbackFieldTypes.Single:
        processSingle(question);
      case FeedbackFieldTypes.Multiple:
        processMultiple(question);
      case FeedbackFieldTypes.Boolean:
        processBoolean(question);
      case FeedbackFieldTypes.FreeAnswer:
        processFreeAnswer(question);
      case FeedbackFieldTypes.Rating:
        processRating(question);
    }
  });

  // Prevent potential id conflicts and remove the id property; the API doesn't expect it.
  processedData = uniqBy(processedData, ({ id }) => id).map(({ id, ...item }) => item);

  return {
    feedback: {
      // TODO Simao: Update the language property to the correct one
      language: 'en',
      feedback_fields_attributes: processedData,
    },
  };
};
