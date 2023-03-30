import { withRouter } from 'next/router';
import dynamic from 'next/dynamic';

const DownloadWindowNoSSR = dynamic(() => import('./DownloadWindow.component'), { ssr: false });

export default withRouter(DownloadWindowNoSSR);
