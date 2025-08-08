/* File             : generic.test.js
   Author           : Test Suite
   Description      : Mocha/Chai test suite for generic.js controller
   Notes            : Tests all handler functions with proper mocking
*/

const { expect } = require('chai');
const sinon = require('sinon');
const proxyquire = require('proxyquire');

describe('Generic Controller Tests', () => {
    let genericController;
    let req, res;
    let loggerStub;
    let getCurrentVersionsStub;
    let manageLoginStub;
    let versionInformation;

    beforeEach(() => {
        // Setup version information
        versionInformation = {
            app: '1.0.0',
            node: '16.0.0'
        };

        // Create logger stub with all required methods
        loggerStub = {
            trace: sinon.stub(),
            debug: sinon.stub(),
            error: sinon.stub(),
            exception: sinon.stub()
        };

        // Create getCurrentVersions stub
        getCurrentVersionsStub = sinon.stub().returns(versionInformation);

        // Create manageLogin stub
        manageLoginStub = {
            manageLogin: sinon.stub()
        };

        // Use proxyquire to inject mocked dependencies
        genericController = proxyquire('../controllers/generic', {
            '../services/generic': {
                logger: loggerStub,
                applicationName: 'TestApp'
            },
            '../services/manageVersion': {
                getCurrentVersions: getCurrentVersionsStub
            },
            '../services/manageLogin': manageLoginStub
        });

        // Setup request and response objects
        req = {
            originalUrl: '/',
            method: 'GET',
            body: {}
        };

        res = {
            render: sinon.stub()
        };
    });

    afterEach(() => {
        sinon.restore();
    });

    describe('unknownHandler', () => {
        it('should render unknown page with version information', async () => {
            req.originalUrl = '/some-unknown-path';
            
            await genericController.main(req, res);
            

            expect(res.render.calledOnce).to.be.true;
            expect(res.render.calledWith('unknown', { currentVersions: versionInformation })).to.be.true;
            expect(loggerStub.error.calledOnce).to.be.true;
            expect(loggerStub.error.calledWith('TestApp:generic:unknownHandler():Unknown Path:[/some-unknown-path].')).to.be.true;
        });

        it('should handle exceptions in unknownHandler', async () => {
            res.render = sinon.stub().throws(new Error('Render error'));
            req.originalUrl = '/unknown';

            await genericController.main(req, res);

            expect(loggerStub.exception.called).to.be.true;
        });
    });

    describe('aboutHandler', () => {
        it('should render about page with version information', async () => {
            req.originalUrl = '/about';

            await genericController.main(req, res);

            expect(res.render.calledOnce).to.be.true;
            expect(res.render.calledWith('about', { currentVersions: versionInformation })).to.be.true;
        });

        it('should handle exceptions in aboutHandler', async () => {
            res.render = sinon.stub().throws(new Error('Render error'));
            req.originalUrl = '/about';

            await genericController.main(req, res);

            expect(loggerStub.exception.called).to.be.true;
        });
    });

    describe('homeHandler', () => {
        it('should render main page with version information', async () => {
            req.originalUrl = '/';

            await genericController.main(req, res);

            expect(res.render.calledOnce).to.be.true;
            expect(res.render.calledWith('main', { currentVersions: versionInformation })).to.be.true;
        });

        it('should handle exceptions in homeHandler', async () => {
            res.render = sinon.stub().throws(new Error('Render error'));
            req.originalUrl = '/';

            await genericController.main(req, res);

            expect(loggerStub.exception.called).to.be.true;
        });
    });

    describe('loginHandler', () => {
        describe('GET requests', () => {
            it('should render login page for GET request', async () => {
                req.originalUrl = '/login';
                req.method = 'GET';

                await genericController.main(req, res);

                expect(res.render.calledOnce).to.be.true;
                expect(res.render.calledWith('login', { currentVersions: versionInformation })).to.be.true;
            });
        });

        describe('POST requests', () => {
            beforeEach(() => {
                req.method = 'POST';
                req.originalUrl = '/login';
            });

            it('should handle valid login POST request', async () => {
                req.body = {
                    userCredential: 'testuser',
                    userPassword: 'testpass'
                };

                const mockQueryResponse = [{ id: 1, userCredential: 'testuser' }];
                manageLoginStub.manageLogin.resolves(mockQueryResponse);

                await genericController.main(req, res);

                expect(manageLoginStub.manageLogin.calledOnce).to.be.true;
                expect(manageLoginStub.manageLogin.calledWith(
                    { action: 'findRecord' },
                    null,
                    { $and: [{ userCredential: 'testuser' }, { userPassword: 'testpass' }] }
                )).to.be.true;
                expect(res.render.calledWith('login', { currentVersions: versionInformation })).to.be.true;
            });

            it('should handle invalid request body', async () => {
                req.body = null;

                await genericController.main(req, res);

                expect(res.render.calledOnce).to.be.true;
                expect(res.render.calledWith('errorPage', { currentVersions: versionInformation })).to.be.true;
                expect(loggerStub.error.called).to.be.true;
            });

            it('should handle manageLogin errors', async () => {
                req.body = {
                    userCredential: 'testuser',
                    userPassword: 'testpass'
                };

                manageLoginStub.manageLogin.rejects(new Error('Database error'));

                await genericController.main(req, res);

                expect(loggerStub.exception.called).to.be.true;
            });
        });

        describe('Unsupported methods', () => {
            it('should log error for unsupported methods', async () => {
                req.originalUrl = '/login';
                req.method = 'PUT';

                await genericController.main(req, res);

                expect(loggerStub.error.calledWith('TestApp:generic:loginHandler():Unsupported method [PUT].')).to.be.true;
            });
        });
    });

    describe('registerHandler', () => {
        it('should render about page for register route', async () => {
            req.originalUrl = '/register';

            await genericController.main(req, res);

            expect(res.render.calledOnce).to.be.true;
            expect(res.render.calledWith('about', { currentVersions: versionInformation })).to.be.true;
        });
    });

    describe('main function', () => {
        it('should handle exceptions in main function', async () => {
            // Force an exception by making originalUrl undefined
            req.originalUrl = undefined;

            await genericController.main(req, res);

            expect(loggerStub.exception.called).to.be.true;
        });
    });

    describe('Edge cases and error scenarios', () => {
        it('should handle missing request properties gracefully', async () => {
            delete req.originalUrl;

            await genericController.main(req, res);

            expect(loggerStub.exception.called).to.be.true;
        });

        it('should handle missing response render method', async () => {
            delete res.render;
            req.originalUrl = '/';

            await genericController.main(req, res);

            expect(loggerStub.exception.called).to.be.true;
        });
    });

    describe('Logging behavior', () => {
        it('should log trace messages at appropriate points', async () => {
            req.originalUrl = '/';

            await genericController.main(req, res);

            // Verify trace logging
            expect(loggerStub.trace.calledWith('TestApp:generic:main():Started')).to.be.true;
            expect(loggerStub.trace.calledWith('TestApp:generic:homeHandler():Started')).to.be.true;
            expect(loggerStub.trace.calledWith('TestApp:generic:homeHandler():Done')).to.be.true;
            expect(loggerStub.trace.calledWith('TestApp:generic:main():Done')).to.be.true;
        });

        it('should log debug messages for login POST requests', async () => {
            req.originalUrl = '/login';
            req.method = 'POST';
            req.body = {
                userCredential: 'testuser',
                userPassword: 'testpass'
            };

            manageLoginStub.manageLogin.resolves([]);

            await genericController.main(req, res);

            expect(loggerStub.debug.calledWith('TestApp:generic:loginHandler():Request Method is [POST].')).to.be.true;
            expect(loggerStub.debug.called).to.be.true;
        });
    });
});