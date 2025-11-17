# ============================================================================
# SSL Certificate Management (Let's Encrypt)
# ============================================================================

.PHONY: ssl-cert-init ssl-cert-renew ssl-setup-cron

## ssl-cert-init: Initialize SSL certificates with Let's Encrypt
ssl-cert-init:
	@echo "$(CYAN)→ Obtaining SSL certificates...$(RESET)"
	@if [ -z "$${SSL_EMAIL}" ]; then \
		echo "$(RED)✗ Error: SSL_EMAIL not set$(RESET)"; \
		exit 1; \
	fi
	@if [ -z "$${API_DOMAIN_NAME}" ]; then \
		echo "$(RED)✗ Error: API_DOMAIN_NAME not set$(RESET)"; \
		exit 1; \
	fi
	@if [ -z "$${KEYCLOAK_DOMAIN_NAME}" ]; then \
		echo "$(RED)✗ Error: KEYCLOAK_DOMAIN_NAME not set$(RESET)"; \
		exit 1; \
	fi
	@docker run --rm --name certbot-temp \
		-v $${COMPOSE_PROJECT_NAME:-openmeal-backend}_certbot_etc:/etc/letsencrypt \
		-v $${COMPOSE_PROJECT_NAME:-openmeal-backend}_certbot_var:/var/lib/letsencrypt \
		-v $${COMPOSE_PROJECT_NAME:-openmeal-backend}_certbot_webroot:/var/www/certbot \
		--network $${DOCKER_NETWORK_NAME:-openmeal_net} \
		certbot/certbot:v2.10.0 certonly \
		--webroot \
		--webroot-path=/var/www/certbot \
		--email $${SSL_EMAIL} \
		--agree-tos \
		--no-eff-email \
		--keep-until-expiring \
		--non-interactive \
		$$(if [ "$${SSL_STAGING}" = "true" ]; then echo "--staging"; fi) \
		-d $${API_DOMAIN_NAME} 2>&1 | grep -E "(Successfully received|Saving debug log|error|Error|failed|Failed)" || true
	@docker run --rm --name certbot-temp \
		-v $${COMPOSE_PROJECT_NAME:-openmeal-backend}_certbot_etc:/etc/letsencrypt \
		-v $${COMPOSE_PROJECT_NAME:-openmeal-backend}_certbot_var:/var/lib/letsencrypt \
		-v $${COMPOSE_PROJECT_NAME:-openmeal-backend}_certbot_webroot:/var/www/certbot \
		--network $${DOCKER_NETWORK_NAME:-openmeal_net} \
		certbot/certbot:v2.10.0 certonly \
		--webroot \
		--webroot-path=/var/www/certbot \
		--email $${SSL_EMAIL} \
		--agree-tos \
		--no-eff-email \
		--keep-until-expiring \
		--non-interactive \
		$$(if [ "$${SSL_STAGING}" = "true" ]; then echo "--staging"; fi) \
		-d $${KEYCLOAK_DOMAIN_NAME} 2>&1 | grep -E "(Successfully received|Saving debug log|error|Error|failed|Failed)" || true
	@if [ -n "$${GRAFANA_DOMAIN_NAME}" ] && [ "$${GRAFANA_DOMAIN_NAME}" != "localhost" ] && [ "$${GRAFANA_DOMAIN_NAME}" != "" ]; then \
		docker run --rm --name certbot-temp \
			-v $${COMPOSE_PROJECT_NAME:-openmeal-backend}_certbot_etc:/etc/letsencrypt \
			-v $${COMPOSE_PROJECT_NAME:-openmeal-backend}_certbot_var:/var/lib/letsencrypt \
			-v $${COMPOSE_PROJECT_NAME:-openmeal-backend}_certbot_webroot:/var/www/certbot \
			--network $${DOCKER_NETWORK_NAME:-openmeal_net} \
			certbot/certbot:v2.10.0 certonly \
			--webroot \
			--webroot-path=/var/www/certbot \
			--email $${SSL_EMAIL} \
			--agree-tos \
			--no-eff-email \
			--keep-until-expiring \
			--non-interactive \
			$$(if [ "$${SSL_STAGING}" = "true" ]; then echo "--staging"; fi) \
			-d $${GRAFANA_DOMAIN_NAME} 2>&1 | grep -E "(Successfully received|Saving debug log|error|Error|failed|Failed)" || true; \
	fi
	@echo "$(GREEN)✓ SSL certificates obtained$(RESET)"
	@if [ -f .env ]; then \
		sed -i 's/^NGINX_CONFIG_TEMPLATE=.*/NGINX_CONFIG_TEMPLATE=default.conf.template/' .env || \
		echo "NGINX_CONFIG_TEMPLATE=default.conf.template" >> .env; \
	else \
		echo "$(RED)✗ Error: .env file not found$(RESET)"; \
		exit 1; \
	fi
	@docker restart $${CONTAINER_PREFIX:-openmeal}-nginx > /dev/null 2>&1
	@echo "$(GREEN)✓ SSL setup complete$(RESET)"

## ssl-cert-renew: Manually renew SSL certificates
ssl-cert-renew:
	@echo "$(GREEN)→ Renewing SSL certificates...$(RESET)"
	@docker run --rm --name certbot-renew \
		-v $${COMPOSE_PROJECT_NAME:-openmeal-backend}_certbot_etc:/etc/letsencrypt \
		-v $${COMPOSE_PROJECT_NAME:-openmeal-backend}_certbot_var:/var/lib/letsencrypt \
		-v $${COMPOSE_PROJECT_NAME:-openmeal-backend}_certbot_webroot:/var/www/certbot \
		--network $${DOCKER_NETWORK_NAME:-openmeal_net} \
		certbot/certbot:v2.10.0 renew --quiet
	@docker exec $${CONTAINER_PREFIX:-openmeal}-nginx nginx -s reload
	@echo "$(GREEN)✓ Certificates renewed and Nginx reloaded$(RESET)"

## ssl-setup-cron: Setup automatic SSL certificate renewal
ssl-setup-cron:
	@echo "$(CYAN)╔════════════════════════════════════════════════════════════════╗$(RESET)"
	@echo "$(CYAN)║         Setup Automatic SSL Certificate Renewal                ║$(RESET)"
	@echo "$(CYAN)╚════════════════════════════════════════════════════════════════╝$(RESET)"
	@echo ""
	@echo "$(YELLOW)This will create a systemd timer or cron job for automatic renewal$(RESET)"
	@echo "$(YELLOW)Platform support: Linux, macOS, Windows (WSL only)$(RESET)"
	@echo ""
	@chmod +x ./scripts/ssl-renew-cron.sh
	@./scripts/ssl-renew-cron.sh install-systemd 2>/dev/null || \
	./scripts/ssl-renew-cron.sh install-cron 2>/dev/null || \
	(echo "$(RED)✗ Error: Automatic renewal not supported on this platform$(RESET)" && \
	 echo "$(YELLOW)→ Supported: Linux (systemd/cron), macOS (cron), Windows (WSL only)$(RESET)" && \
	 echo "$(YELLOW)→ Please manually run 'make ssl-cert-renew' monthly$(RESET)" && \
	 exit 1)
	@echo ""
	@echo "$(GREEN)✓ Automatic renewal configured$(RESET)"
	@echo "$(CYAN)→ Certificates will be checked and renewed automatically$(RESET)"
