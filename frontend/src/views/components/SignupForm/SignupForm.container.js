import { reduxForm } from 'redux-form';

import { SignupSchema, signup, signin, login } from '@modules/user';

import { asyncValidate } from '@views/utils/asyncValidate';

import SignupForm from './SignupForm.component';

export default reduxForm({
  form: 'SignupForm',
  asyncValidate: asyncValidate(SignupSchema),
  onSubmit: async values => {
    await signup(values);
    const auth_token = await signin(values);

    return auth_token;
  },
  onSubmitSuccess: (auth_token, dispatch) => {
    dispatch(login(auth_token));
  },
})(SignupForm);
