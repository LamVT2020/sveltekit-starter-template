class AuthModalState {
	isOpen = $state(false);
	redirectUrl = $state<string | null>(null);
	error = $state<string | null>(null);

	open(options?: { redirectUrl?: string | null; error?: string | null } | string) {
		if (typeof options === 'string') {
			this.redirectUrl = options;
			this.error = null;
		} else {
			this.redirectUrl = options?.redirectUrl ?? null;
			this.error = options?.error ?? null;
		}
		this.isOpen = true;
	}

	close() {
		this.isOpen = false;
		this.error = null;
	}
}

export const authModal = new AuthModalState();
