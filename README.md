## Anti-Captcha SuperProxy

SuperProxy is a all-in-one Captcha Solving Server which includes captcha solving API, administration and customers web-interface.
Its backbone API service is [Anti-Captcha.com](https://anti-captcha.com) API, which is connected with a customer API key.
You can use SuperProxy as a proxy service for your API requests or sell captcha solving services to your own customers.

### Features
- Captcha solving API (Anti-Captcha V2 protocol).
- Web-interface for managing users, administration of the system, viewing stats, etc.
- Unlimited sub-accounting, separate statistics and billing per account.
- Allow registration of your own new customers. Protect login/registration form with captcha.
- White-labeling. Set your logo, landing page, contacts, company name.
- Set custom pricing for your customers per captcha type.
- Customized payment options for your customers and payments API.
- Documentation included in all languages.
- Languages: English, Spanish, Brazil, Russian, Ukrainian, French, Italian, German, Polish, Dutch, Turkish, Indonesian, Chinese, Vietnamese, Japanese.
- Support of your own SSL certificate.

### Requirements
- VPS or dedicated server with Ubuntu OS and open web ports (80 and 443), root access. 
- Minimum 1Gb of RAM.
- A domain name. 
- (optional) Wildcard SSL certificate.

### Installation
The following will download, install and run all required packages. You will be prompted several questions in order to setup NGINX server and add administrator user.
```bash
curl -O https://raw.githubusercontent.com/anti-captcha/superproxy/main/start.sh
chmod +x start.sh
./start.sh
```
After the installation is finished, you'll be left with a __docker-compose.yml__ file, with which you can start and stop your server.
To start the server:
```bash
cd project_directory
docker-compose up -d
```
To stop the server:
```bash
cd project_directory
docker-compose down
```

### SSL certificate notes
If you decide to use SSL certificate, it should be of type wildcard or support 2 domains:
1. The one for user interface. (Example: https://your-captcha-service.com/)
2. API domain. (Example: https://api.your-captcha-service.com/)

## Administration Settings
This section describes administrator settings and payment links integration.

### API settings
Location: __/console/admin-settings__ 

__API KEY__  
Set your anti-captcha.com API key here. Always make sure you have positive account balance and all notifications enabled. If the balance drops below $0, then all of your customers will receive API error ERROR_BACKEND_ERROR.

__Queues Settings__  
Manage Queue prices, set currency and ratio labels. The queue prices are set in USD, but your customers may see their balance in their own currency. 
For example, you'd like to system's statistics currency to be Brazilian Real. In the currency symbol text input you'd then put "__R$__" and for the currency ratio you'd use value __0.18__. Then, your customers will see their balance in spendings in R$.

__Customers Sign In Settings__  
Register a new Recaptcha __V3__  keypair and use them to protect your login form. You can also enable/disable registration here (disabled by default).

__Email settings__  
SuperProxy uses [Elastic Email](https://elasticemail.com) API service to deliver emails, which are used to send registration and password recovery emails. Leave it empty if you're not expecting user registrations.
In order to work properly make sure that the "From" email's domain name matches the one you've setup in ElasticEmail.

__Payment API Settings__  
Use this to change your payment API key. Do not make it short or easy to bruteforce.

__White-Label__  
The descriptions are pretty self-explanatory. Post an issue if you have a question.

### Payment options
Location: __/console/admin-payment-options__  

At this moment you can only provide payment links to your customers and apply payments via API. Post an issue if you want us to program a specific payment provider integration.
Each payment link can contain user's ID and email address, which you may use later to add funds with API.
For example, you can add links to a certain payment provider and encode user's ID and/or email within the link:  
Add user ID: https://payment-provider.com/?pay&userid=$userid  
Add user's email https://payment-provider.com/?pay&email=$email  
And then implement a payment success "postback" which will notify SuperProxy about new payment via Payment API.

#### Payment API
Location: __/api/external/addFunds__  
Method: JSON POST  

Adds funds to a user account by its ID or email. Integrate it with your payment method solution.

| Property | Type | Description                                   |
|----------| --- |-----------------------------------------------|
| secret   | string | Secret key from Payment API Settings          |
| user_id  | int | User's ID _or_                                |
| email    | string | User's email                                  |
| amount   | double | Payment amount                                |
| comment  | string | Comment, will appear in users finance history |
| payload  | json | Custom payload for later usage                |

Example:
```bash
curl -i -X POST \
-H "Accept: application/json" \
-H "Content-Type: application/json" \
-d '{
    "secret":"aeff279584199a6f9b5914c[---cut-too-long---]db68cc87d524fbe0f1f0b1aad60cb",
    "email": "gooduser@gmail.com"
    "amount": 10.5,
    "comment": "Topup for $10.5"
}' https://your-captcha-website.com/api/external/addFunds
```

## Troubles, bugs and feature requests
Feel free to post your questions and ideas in Issues.

