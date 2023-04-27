import * as Yup from 'yup';

const VALIDATION_ERRORS = {
  required: 'This is a required question',
};

export const IntroSchema = Yup.object().shape({
  work_sector: Yup.string().required(VALIDATION_ERRORS.required),
  gender: Yup.string().required(VALIDATION_ERRORS.required),
  location: Yup.string().required(VALIDATION_ERRORS.required),
  projects_locations: Yup.array().required(VALIDATION_ERRORS.required),
});

export const ToolUseSchema = Yup.object().shape({
  usage: Yup.string().required(VALIDATION_ERRORS.required),
});

export const MapSchema = Yup.object().shape({});

export const WebsiteSchema = Yup.object().shape({});
