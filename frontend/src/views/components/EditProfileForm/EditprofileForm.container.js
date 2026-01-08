import { compose } from 'redux';
import { connect } from 'react-redux';
import { reduxForm } from 'redux-form';

import { EditProfileSchema, loadUserData, editProfile } from 'state/modules/user';

import { asyncValidate } from 'views/utils/asyncValidate';

import EditProfileForm from './EditProfileForm.component';

const mapStateToProps = (state) => ({
  user: state.user,
  initialValues: {
    ...state.user,
  },
});

const withConnect = connect(mapStateToProps);

const withForm = reduxForm({
  form: 'EditProfileForm',
  asyncValidate: asyncValidate(EditProfileSchema),
  onSubmit: editProfile,
  onSubmitSuccess: (_, dispatch) => dispatch(loadUserData()),
});

export default compose(withConnect, withForm)(EditProfileForm);
