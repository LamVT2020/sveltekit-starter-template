const dotenv = require('dotenv');
const path = require('path');

dotenv.config({ path: path.resolve(__dirname, '.env') });

module.exports = {
	apps: [
		{
			name: 'sveltekit-starter-template',
			script: 'build/index.js',
			instances: 1,
			autorestart: true,
			watch: false,
			max_memory_restart: '500M',
			env: {
				NODE_ENV: 'production',
				PORT: process.env.PORT || 3000
			}
		}
	]
};
