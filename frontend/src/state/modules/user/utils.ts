import * as Yup from 'yup';
import { AUTH_TOKEN } from 'utilities/constants';

// LOGIN FORM //
export interface ILoginForm {
  email: string;
  password: string;
}

export const LoginSchema = Yup.object().shape({
  email: Yup.string().email('Invalid email').required('Email is required'),
  password: Yup.string()
    .min(8, 'Password is too short!')
    .max(50, 'Password is too long!')
    .required('Password is requred'),
});

// SIGNUP FORM //
export interface ISignupForm {
  email: string;
  password: string;
  password_confirmation: string;
  first_name: string;
  last_name: string;
  organization: string;
  organization_role: string;
}

export const SignupSchema = Yup.object().shape({
  email: Yup.string().email('Invalid email').required('Email is required'),

  password: Yup.string()
    .min(8, 'Password is too short!')
    .max(50, 'Password is too long!')
    .required('Password is requred'),

  password_confirmation: Yup.string().oneOf([Yup.ref('password'), null], 'Passwords must match'),

  first_name: Yup.string(),
  last_name: Yup.string(),
  organization: Yup.string(),
  organization_role: Yup.string(),
});

// EDIT PROFILE FORM //
export interface IEditProfileForm {
  email: string;
  first_name: string;
  last_name: string;
  organization: string;
  organization_role: string;
}

export const EditProfileSchema = Yup.object().shape({
  email: Yup.string().email('Invalid email').required('Email is required'),

  first_name: Yup.string(),
  last_name: Yup.string(),
  organization: Yup.string(),
  organization_role: Yup.string(),
});

// PROFILE SETTINGS FORM (with password) //
export interface IProfileSettingsForm {
  email: string;
  password?: string;
  password_confirmation?: string;
}

export const ProfileSettingsSchema = Yup.object().shape({
  email: Yup.string().email('Invalid email').required('Email is required'),

  password: Yup.string()
    .min(8, 'Password is too short!')
    .max(50, 'Password is too long!')
    .nullable()
    .transform((value) => (value === '' ? null : value)),

  password_confirmation: Yup.string()
    .nullable()
    .transform((value) => (value === '' ? null : value))
    .when('password', {
      is: (val: string | null) => val && val.length > 0,
      then: (schema) => schema.oneOf([Yup.ref('password')], 'Passwords must match'),
    }),
});

// Utils

export const getToken = () => localStorage.getItem(AUTH_TOKEN);
