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
    const { router } = props;
    const { query: { from = '/' } = {} } = router;

    dispatch(login(auth_token));

    if (from && router.isReady) {
      router.push(from);
    }
  },
});

export default compose(withRouter, withForm)(LoginForm);
