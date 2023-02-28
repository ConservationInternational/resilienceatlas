import { compose } from 'redux';
import { connect } from 'react-redux';
import { reduxForm } from 'redux-form';

import {
  EditProfileSchema,
  editProfile,
  userProfileEdited,
} from '@modules/user';

import { asyncValidate } from '@views/utils/asyncValidate';

import ProfileSettingsForm from './ProfileSettingsForm.component';

const mapStateToProps = state => ({
  user: state.user,
  initialValues: {
    email: state.user.email,
  },
});

const withConnect = connect(mapStateToProps);

const withForm = reduxForm({
  form: 'ProfileSettingsForm',
  asyncValidate: asyncValidate(EditProfileSchema),
  onSubmit: editProfile,
  onSubmitSuccess: (result, dispatch) => {
    dispatch(userProfileEdited(result));
  },
});

export default compose(withConnect, withForm)(ProfileSettingsForm);
