import { compose } from 'redux';
import { reduxForm } from 'redux-form';
import { withRouter } from 'react-router-dom';

import { LoginSchema, signin, login } from '@modules/user';

import { asyncValidate } from '@views/utils/asyncValidate';

import LoginForm from './LoginForm.component';

const withForm = reduxForm({
  form: 'LoginForm',
  asyncValidate: asyncValidate(LoginSchema),
  onSubmit: signin,
  onSubmitSuccess: (auth_token, dispatch, props) => {
    const {
      history,
      location: { state: { from, ...state } = {} },
    } = props;

    dispatch(login(auth_token));

    if (from) {
      history.push(from, state);
    }
  },
});

export default compose(withRouter, withForm)(LoginForm);
