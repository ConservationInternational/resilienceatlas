import { connect } from 'react-redux';
import { load as loadMenuItems, makeMenuTree } from 'state/modules/map_menu_entries';
import { logout, getUserLoggedIn } from 'state/modules/user';
import Component from './component';

const makeMapStateToProps = () => {
  const getMenuItems = makeMenuTree();

  const mapStateToProps = (state) => ({
    loggedIn: getUserLoggedIn(state),
    site: state.site,
    menuItems: getMenuItems(state),
    menuItemsLoaded: state.map_menu_entries.loaded,
  });

  return mapStateToProps;
};

export default connect(makeMapStateToProps, { loadMenuItems, logout })(Component);
