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

// Utils

export const getToken = () => localStorage.getItem(AUTH_TOKEN);
