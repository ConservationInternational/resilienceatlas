import { compose } from 'redux';
import { reduxForm } from 'redux-form';
import { withRouter } from 'next/router';

import { LoginSchema, signin, login } from 'state/modules/user';

import { asyncValidate } from 'views/utils/asyncValidate';

import LoginForm from './LoginForm.component';

const withForm = reduxForm({
  form: 'LoginForm',
  asyncValidate: asyncValidate(LoginSchema),
  onSubmit: signin,
  onSubmitSuccess: (auth_token, dispatch, props) => {
    const {
      router: { query: { from } = {} },
    } = props;

    dispatch(login(auth_token));

    if (from) {
      router.push(from);
    }
  },
});

export default compose(withRouter, withForm)(LoginForm);
